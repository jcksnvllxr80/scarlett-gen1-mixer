//
//  MixerModel.swift
//  ScarlettGen1Mixer
//
//  Keeps the device open while the window is open: sends queued writes, polls
//  meters about 30 times a second and the full mixer state every 2 seconds.
//  Writes: mixer gains only so far (the only write type confirmed on hardware).
//

import Foundation
import Observation
import ScarlettKit

@MainActor
@Observable
final class MixerModel {
    private(set) var state: MixerState?
    private(set) var meters: Meters?
    private(set) var status = "Looking for a Scarlett…"
    /// Sample rate and clock source as macOS reports them (follows Audio MIDI Setup, DAWs and this app).
    private(set) var clock = CoreAudioClock.Snapshot()
    @ObservationIgnored private var coreAudioClock: CoreAudioClock?

    /// Changes the sample rate through macOS. The interface's settings are re-read once afterwards.
    func setSampleRate(_ hz: Double) {
        guard hz != clock.rate else { return }
        coreAudioClock?.setRate(hz)
        Task { try? await Task.sleep(for: .seconds(2)); refresh() }
    }

    /// Changes the clock source (Internal / S/PDIF / ADAT) through macOS.
    func setClockSource(_ id: UInt32) {
        guard id != clock.source else { return }
        coreAudioClock?.setSource(id)
    }
    var autoRefresh = true
    private var refreshRequested = false
    /// Writes waiting to be sent by the polling loop, keyed so only the latest value per control is sent.
    private var pendingWrites: [String: ScarlettDevice.WriteRequest] = [:]
    private var pendingOrder: [String] = []

    /// Sets a mixer gain: updates the view immediately and queues the write.
    func setGain(input i: Int, mix m: Int, dB: Double) {
        let req = ScarlettDevice.mixerGainRequest(input: i, mix: m, dB: dB)
        enqueue(req)
        if state?.inputs.indices.contains(i) == true, state?.inputs[i].gains.indices.contains(m) == true {
            state?.inputs[i].gains[m] = max(dB, -128)
        }
    }

    // MARK: Controls (app logic on top of documented writes)

    /// Settings the device can't report (write-only); the app remembers them.
    private(set) var dim = false
    private(set) var monitorMute = false
    private(set) var mono = false
    /// Saved L/R gains for muted channels, keyed "input-pair".
    private(set) var mutedGains: [String: (Double, Double)] = [:]
    /// Soloed channel per mix pair (input index), if any.
    private(set) var solo: [Int: Int] = [:]
    private var soloSaved: [String: (Double, Double)] = [:]
    /// Stereo-linked odd channels (0-based odd input index i pairs i and i+1), per mix pair.
    var linked: Set<Int> = Set(stride(from: 0, to: 18, by: 2)) { didSet { isModified = true } }   // every odd/even pair starts as stereo

    /// Monitored line outputs (1…10). Matches the device's hardware-knob mask set at connect.
    var monitoredPairs = 1...3       // Line pairs 1/2, 3/4, 5/6

    func gains(_ i: Int, pair p: Int) -> (Double, Double) {
        let g = state?.inputs[safe: i]?.gains
        return ((g?[safe: 2 * p] ?? nil) ?? -128, (g?[safe: 2 * p + 1] ?? nil) ?? -128)
    }

    func setPair(_ i: Int, pair p: Int, _ l: Double, _ r: Double) {
        setGain(input: i, mix: 2 * p, dB: l)
        setGain(input: i, mix: 2 * p + 1, dB: r)
    }

    func isMuted(_ i: Int, pair p: Int) -> Bool { mutedGains["\(i)-\(p)"] != nil }

    func toggleMute(_ i: Int, pair p: Int) {
        let key = "\(i)-\(p)"
        if let saved = mutedGains.removeValue(forKey: key) {
            setPair(i, pair: p, saved.0, saved.1)
        } else {
            mutedGains[key] = gains(i, pair: p)
            setPair(i, pair: p, -128, -128)
        }
    }

    func toggleSolo(_ i: Int, pair p: Int) {
        guard let s = state else { return }
        if solo[p] == i {                       // un-solo: restore everyone
            solo[p] = nil
            for (key, g) in soloSaved where key.hasSuffix("-\(p)") {
                if let input = Int(key.split(separator: "-")[0]) { setPair(input, pair: p, g.0, g.1) }
            }
            soloSaved = soloSaved.filter { !$0.key.hasSuffix("-\(p)") }
            return
        }
        if solo[p] != nil { toggleSolo(solo[p]!, pair: p) }   // only one solo at a time
        solo[p] = i
        let partner = linked.contains(i) ? i + 1 : (linked.contains(i - 1) ? i - 1 : i)
        for input in s.inputs.map(\.index) where input != i && input != partner {
            soloSaved["\(input)-\(p)"] = gains(input, pair: p)
            setPair(input, pair: p, -128, -128)
        }
    }

    func setMixerInputSource(_ i: Int, _ source: Source) {
        guard let m = state?.model else { return }
        enqueue(ScarlettDevice.mixerInputSourceRequest(input: i, source: source, model: m))
        state?.inputs[i].source = source
    }

    func setOutputSource(_ n: Int, _ source: Source) {
        guard let s = state else { return }
        enqueue(ScarlettDevice.outputSourceRequest(output: n, source: source, model: s.model))
        let k = n / 2
        if n % 2 == 0 { state?.outputs[k].left.source = source } else { state?.outputs[k].right.source = source }
    }

    func setCaptureSource(_ c: Int, _ source: Source) {
        guard let s = state else { return }
        enqueue(ScarlettDevice.captureSourceRequest(channel: c, source: source, model: s.model))
        state?.capture[c] = source
    }

    private var monitoredBuses: [Int] { monitoredPairs.flatMap { [2 * $0 - 1, 2 * $0] } }

    func toggleDim() { dim.toggle(); enqueue(ScarlettDevice.monitorDimRequest(dim)) }
    func toggleMonitorMute() { monitorMute.toggle(); enqueue(ScarlettDevice.monitorMuteRequest(monitorMute)) }
    func toggleMono() {
        mono.toggle()
        for p in 1...5 { enqueue(ScarlettDevice.monoRequest(pair: p, mono && monitoredPairs.contains(p))) }
    }
    func togglePad() {
        let on = !(state?.padOn ?? false)
        enqueue(ScarlettDevice.padRequest(on))
        state?.padOn = on
    }
    /// L or R mute: mutes the odd (L) or even (R) monitored outputs.
    func sideMuted(left: Bool) -> Bool {
        guard let s = state else { return false }
        let buses = monitoredBuses.filter { left ? $0 % 2 == 1 : $0 % 2 == 0 }
        return !buses.isEmpty && buses.allSatisfy { b in
            let o = s.outputs[(b - 1) / 2]
            return (b % 2 == 1 ? o.left.muted : o.right.muted) == true
        }
    }
    func toggleSide(left: Bool) {
        let mute = !sideMuted(left: left)
        for b in monitoredBuses where (b % 2 == 1) == left {
            enqueue(ScarlettDevice.outputMuteRequest(bus: b, muted: mute))
            if b % 2 == 1 { state?.outputs[(b - 1) / 2].left.muted = mute } else { state?.outputs[(b - 1) / 2].right.muted = mute }
        }
    }

    // MARK: Source names (user-defined, saved between launches)

    var sourceNames: [String: String] = (UserDefaults.standard.dictionary(forKey: "sourceNames") as? [String: String]) ?? [:] {
        didSet { UserDefaults.standard.set(sourceNames, forKey: "sourceNames"); isModified = true }
    }
    func name(_ s: Source) -> String? {
        guard let n = sourceNames["\(s)"], !n.isEmpty else { return nil }
        return n
    }
    func rename(_ s: Source, _ newName: String) {
        sourceNames["\(s)"] = newName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: Mono / stereo mixes (generic over a list of mixes: [L, R] or [single])

    /// Mix pairs (0 = mixes 1/2 …) currently used as two mono mixes.
    var monoPairs: Set<Int> = [] { didSet { isModified = true } }

    func gain(_ i: Int, mix m: Int) -> Double { (state?.inputs[safe: i]?.gains[safe: m] ?? nil) ?? -128 }

    private var mutedSaved: [String: [Double]] = [:]
    private func key(_ i: Int, _ mixes: [Int]) -> String { "\(i)@\(mixes)" }
    func isMuted(_ i: Int, mixes: [Int]) -> Bool { mutedSaved[key(i, mixes)] != nil }
    func toggleMute(_ i: Int, mixes: [Int]) {
        let k = key(i, mixes)
        if let saved = mutedSaved.removeValue(forKey: k) {
            for (m, v) in zip(mixes, saved) { setGain(input: i, mix: m, dB: v) }
        } else {
            mutedSaved[k] = mixes.map { gain(i, mix: $0) }
            for m in mixes { setGain(input: i, mix: m, dB: -128) }
        }
    }

    private(set) var soloOf: [String: Int] = [:]
    private var soloSavedM: [String: [Double]] = [:]
    func soloed(_ mixes: [Int]) -> Int? { soloOf["\(mixes)"] }
    func toggleSolo(_ i: Int, mixes: [Int]) {
        guard let s = state else { return }
        let mk = "\(mixes)"
        if soloOf[mk] == i {
            soloOf[mk] = nil
            for (k, v) in soloSavedM where k.hasSuffix("@\(mixes)") {
                if let input = Int(k.split(separator: "@")[0]) {
                    for (m, g) in zip(mixes, v) { setGain(input: input, mix: m, dB: g) }
                }
            }
            soloSavedM = soloSavedM.filter { !$0.key.hasSuffix("@\(mixes)") }
            return
        }
        if let cur = soloOf[mk] { toggleSolo(cur, mixes: mixes) }
        soloOf[mk] = i
        let partner = linked.contains(i) ? i + 1 : (linked.contains(i - 1) ? i - 1 : i)
        for input in s.inputs.map(\.index) where input != i && input != partner {
            soloSavedM[key(input, mixes)] = mixes.map { gain(input, mix: $0) }
            for m in mixes { setGain(input: input, mix: m, dB: -128) }
        }
    }

    // MARK: Setups (save / open / save to interface)

    /// The open setup file, if any, and whether anything changed since it was saved or opened.
    private(set) var setupURL: URL?
    var isModified = false
    var recentSetups: [URL] = (UserDefaults.standard.stringArray(forKey: "recentSetups") ?? []).map { URL(fileURLWithPath: $0) } {
        didSet { UserDefaults.standard.set(recentSetups.map(\.path), forKey: "recentSetups") }
    }

    struct SetupFile: Codable {
        var version = 1
        var productID: UInt16
        var outputs: [Int16]          // per output (L/R interleaved), raw source values
        var capture: [Int16]          // per channel recorded to the computer
        var inputSources: [Int16]     // per mixer channel
        var gains: [[Double]]         // [channel][mix] in dB, −128 = −∞
        var dim: Bool
        var monitorMute: Bool
        var mono: Bool
        var pad: Bool
        var linked: [Int]
        var monoPairs: [Int]
        var names: [String: String]
        var outputMutes: [Bool]? = nil   // per output (L/R interleaved); missing in older files
    }

    func currentSetup() -> SetupFile? {
        guard let s = state else { return nil }
        let m = s.model
        return SetupFile(
            productID: m.productID,
            outputs: s.outputs.flatMap { [($0.left.source ?? .off).raw(model: m), ($0.right.source ?? .off).raw(model: m)] },
            capture: s.capture.map { ($0 ?? .off).raw(model: m) },
            inputSources: s.inputs.map { ($0.source ?? .off).raw(model: m) },
            gains: s.inputs.map { $0.gains.map { $0 ?? -128 } },
            dim: dim, monitorMute: monitorMute, mono: mono, pad: s.padOn == true,
            linked: linked.sorted(), monoPairs: monoPairs.sorted(), names: sourceNames,
            outputMutes: s.outputs.flatMap { [$0.left.muted == true, $0.right.muted == true] })
    }

    /// Sends a whole setup to the device and adopts its app-side settings.
    func apply(_ f: SetupFile) throws {
        guard let s = state else { throw SetupError.noDevice }
        let m = s.model
        guard f.productID == m.productID else { throw SetupError.wrongModel }
        for (n, raw) in f.outputs.enumerated() where n < s.outputs.count * 2 { setOutputSource(n, Source(raw: raw, model: m)) }
        for (c, raw) in f.capture.enumerated() where c < s.capture.count { setCaptureSource(c, Source(raw: raw, model: m)) }
        for (i, raw) in f.inputSources.enumerated() where i < s.inputs.count { setMixerInputSource(i, Source(raw: raw, model: m)) }
        for (i, row) in f.gains.enumerated() where i < s.inputs.count {
            for (mix, dB) in row.enumerated() where mix < m.mixes { setGain(input: i, mix: mix, dB: dB) }
        }
        dim = f.dim; enqueue(ScarlettDevice.monitorDimRequest(f.dim))
        monitorMute = f.monitorMute; enqueue(ScarlettDevice.monitorMuteRequest(f.monitorMute))
        mono = f.mono
        for p in 1...5 { enqueue(ScarlettDevice.monoRequest(pair: p, f.mono && monitoredPairs.contains(p))) }
        enqueue(ScarlettDevice.padRequest(f.pad)); state?.padOn = f.pad
        // Output mutes (e.g. the L / R monitor mutes); bus = output index + 1
        for (n, muted) in (f.outputMutes ?? []).enumerated() where n < s.outputs.count * 2 {
            enqueue(ScarlettDevice.outputMuteRequest(bus: n + 1, muted: muted))
            if n % 2 == 0 { state?.outputs[n / 2].left.muted = muted } else { state?.outputs[n / 2].right.muted = muted }
        }
        mutedSaved = [:]; soloOf = [:]; soloSavedM = [:]
        linked = Set(f.linked); monoPairs = Set(f.monoPairs); sourceNames = f.names
        isModified = false
    }

    func save(to url: URL) throws {
        guard let f = currentSetup() else { throw SetupError.noDevice }
        let enc = JSONEncoder(); enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        try enc.encode(f).write(to: url)
        setupURL = url; isModified = false; noteRecent(url)
    }

    func open(_ url: URL) throws {
        let f = try JSONDecoder().decode(SetupFile.self, from: Data(contentsOf: url))
        try apply(f)
        setupURL = url; isModified = false; noteRecent(url)
    }

    private func noteRecent(_ url: URL) {
        recentSetups = ([url] + recentSetups.filter { $0 != url }).prefix(8).map { $0 }
    }

    /// The 18i20's power-on defaults (observed on the user's device after a power cycle).
    func factorySetup() -> SetupFile? {
        guard let s = state, s.model == .scarlett18i20 else { return nil }
        let m = s.model
        let outputs: [Source] = (0..<20).map { n in n < 10 ? .mix(n % 2) : .off }
        let capture: [Source] = (1...8).map { .analog($0) } + (1...2).map { .spdif($0) } + (1...8).map { .adat($0) }
        let inputs: [Source] = (1...8).map { .analog($0) } + Array(repeating: .off, count: 8) + [.daw(1), .daw(2)]
        return SetupFile(productID: m.productID,
                         outputs: outputs.map { $0.raw(model: m) }, capture: capture.map { $0.raw(model: m) },
                         inputSources: inputs.map { $0.raw(model: m) },
                         gains: Array(repeating: Array(repeating: 0, count: m.mixes), count: 18),
                         dim: false, monitorMute: false, mono: false, pad: false,
                         linked: Array(stride(from: 0, to: 18, by: 2)), monoPairs: [], names: [:],
                         outputMutes: Array(repeating: false, count: 20))
    }

    func newSetupState() { setupURL = nil; isModified = false }

    func saveToHardware() { enqueue(ScarlettDevice.saveToHardwareRequest()) }

    enum SetupError: LocalizedError {
        case noDevice, wrongModel
        var errorDescription: String? {
            switch self {
            case .noDevice: "No Scarlett is connected."
            case .wrongModel: "This setup was saved for a different Scarlett model."
            }
        }
    }

    private func enqueue(_ w: ScarlettDevice.WriteRequest) {
        isModified = true
        let key = "\(w.bRequest)-\(w.entity)-\(w.wValue)"
        if pendingWrites[key] == nil { pendingOrder.append(key) }
        pendingWrites[key] = w
    }

    private func takePendingWrites() -> [ScarlettDevice.WriteRequest] {
        defer { pendingWrites = [:]; pendingOrder = [] }
        return pendingOrder.compactMap { pendingWrites[$0] }
    }

    private var loop: Task<Void, Never>?

    func start() {
        guard loop == nil else { return }
        coreAudioClock = CoreAudioClock { [weak self] snap in self?.clock = snap }
        loop = Task.detached(priority: .userInitiated) { [weak self] in
            var device: ScarlettDevice?
            var lastFullRead = Date.distantPast
            var lastSyncRead = Date.distantPast
            while !Task.isCancelled {
                guard let self else { break }
                if device == nil {
                    do {
                        device = try ScarlettDevice.openFirst()
                        lastFullRead = .distantPast
                    } catch {
                        await self.disconnected("\(error)")
                        try? await Task.sleep(for: .seconds(1))
                        continue
                    }
                }
                guard let dev = device else { continue }
                do {
                    // Send queued writes first; then re-read the full state soon after.
                    let writes = await self.takePendingWrites()
                    for w in writes { WriteLog.append(w); try dev.send(w) }
                    // No re-read after writes: the app's own state already reflects them.
                    // Meters double as the connection check: a failure means the device went away.
                    let meters = try dev.readMeters()
                    var state: MixerState?
                    let requested = await self.consumeRefreshRequest()
                    let auto = await self.autoRefresh
                    // Like Focusrite's software: read the full mixer state once per connection
                    // (or on explicit refresh), then poll only meters, knob and sync.
                    _ = auto
                    let wantFull = requested || lastFullRead == .distantPast
                    if wantFull {
                        let firstRead = lastFullRead == .distantPast
                        state = dev.readState(readPad: firstRead)
                        if !firstRead, let pad = await self.state?.padOn { state?.padOn = pad }
                        lastFullRead = .now
                    }
                    // Sync status (MEM 0x3c/0x0002, 1 byte) about once a second, as Focusrite's software does.
                    var sync: Bool?
                    if Date().timeIntervalSince(lastSyncRead) >= 1 {
                        sync = try? dev.syncLocked()
                        lastSyncRead = .now
                    }
                    await self.update(meters: meters, state: state)
                    if let sync { await self.setSync(sync) }
                } catch {
                    dev.close()
                    device = nil
                    await self.disconnected("\(error)")
                }
                try? await Task.sleep(for: .milliseconds(33))
            }
            // Shutting down: send any changes still queued, then close the device.
            if let dev = device {
                for w in await self?.takePendingWrites() ?? [] { WriteLog.append(w); try? dev.send(w) }
                dev.close()
            }
        }
    }

    /// Stops polling after the current request finishes, flushes queued writes and closes the device.
    func shutdown() async {
        guard let loop else { return }
        loop.cancel()
        await loop.value
        self.loop = nil
    }

    /// Asks the polling loop to re-read the full state on its next pass.
    func refresh() { refreshRequested = true }

    private func consumeRefreshRequest() -> Bool {
        defer { refreshRequested = false }
        return refreshRequested
    }

    private func setSync(_ locked: Bool) { state?.syncLocked = locked }

    private func update(meters: Meters?, state: MixerState?) {
        self.meters = meters
        if let state { self.state = state }
        status = "Connected"
    }

    private func disconnected(_ message: String) {
        state = nil
        meters = nil
        status = message
    }
}


/// Appends every write the app sends to ~/Library/Logs/ScarlettGen1Mixer-writes.log (for tracing device hangs).
enum WriteLog {
    nonisolated static func append(_ w: ScarlettDevice.WriteRequest) {
        guard let home = ProcessInfo.processInfo.environment["HOME"] else { return }
        let url = URL(fileURLWithPath: home + "/Library/Logs/ScarlettGen1Mixer-writes.log")
        let line = ISO8601DateFormatter().string(from: Date()) + " " + w.description + "\n"
        if let h = try? FileHandle(forWritingTo: url) {
            h.seekToEndOfFile(); h.write(Data(line.utf8)); try? h.close()
        } else {
            try? Data(line.utf8).write(to: url)
        }
    }
}
