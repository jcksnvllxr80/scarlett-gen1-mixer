//
//  CoreAudioClock.swift
//  ScarlettGen1Mixer
//
//  The interface's sample rate and clock source, through CoreAudio (the same settings as
//  Audio MIDI Setup). Follows changes made anywhere and can change them. Nothing is sent to
//  the device by this app: macOS (usbaudiod) applies the change.
//

import CoreAudio
import Foundation

@MainActor
final class CoreAudioClock {
    struct Snapshot: Equatable {
        var rate: Double?
        var rates: [Double] = []
        var source: UInt32?
        var sources: [(id: UInt32, name: String)] = []
        static func == (a: Snapshot, b: Snapshot) -> Bool {
            a.rate == b.rate && a.rates == b.rates && a.source == b.source && a.sources.map(\.id) == b.sources.map(\.id)
        }
        var sourceName: String? { sources.first { $0.id == source }?.name }
    }

    private let onChange: (Snapshot) -> Void
    private var device = AudioObjectID(kAudioObjectUnknown)
    private var listener: AudioObjectPropertyListenerBlock?
    private var devicesListener: AudioObjectPropertyListenerBlock?

    private static func address(_ s: AudioObjectPropertySelector) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: s, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
    }
    private static let watched = [kAudioDevicePropertyNominalSampleRate, kAudioDevicePropertyClockSource,
                                  kAudioDevicePropertyAvailableNominalSampleRates]

    init(onChange: @escaping (Snapshot) -> Void) {
        self.onChange = onChange
        // Re-find the interface when devices come and go (replugging changes its CoreAudio ID).
        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in MainActor.assumeIsolated { self?.attach() } }
        devicesListener = block
        var a = Self.address(kAudioHardwarePropertyDevices)
        AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &a, .main, block)
        attach()
    }

    // MARK: Changing

    func setRate(_ hz: Double) {
        guard device != kAudioObjectUnknown else { return }
        var a = Self.address(kAudioDevicePropertyNominalSampleRate)
        var v = Float64(hz)
        AudioObjectSetPropertyData(device, &a, 0, nil, UInt32(MemoryLayout<Float64>.size), &v)
    }

    func setSource(_ id: UInt32) {
        guard device != kAudioObjectUnknown else { return }
        var a = Self.address(kAudioDevicePropertyClockSource)
        var v = id
        AudioObjectSetPropertyData(device, &a, 0, nil, UInt32(MemoryLayout<UInt32>.size), &v)
    }

    // MARK: Following

    private func attach() {
        let found = Self.findScarlett()
        guard found != device else { return }
        if device != kAudioObjectUnknown, let old = listener {
            for s in Self.watched { var a = Self.address(s); AudioObjectRemovePropertyListenerBlock(device, &a, .main, old) }
        }
        device = found
        listener = nil
        guard found != kAudioObjectUnknown else { onChange(Snapshot()); return }
        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in MainActor.assumeIsolated { self?.report() } }
        listener = block
        for s in Self.watched { var a = Self.address(s); AudioObjectAddPropertyListenerBlock(found, &a, .main, block) }
        report()
    }

    private func report() {
        var snap = Snapshot()
        var a = Self.address(kAudioDevicePropertyNominalSampleRate)
        var rate = Float64(0), size = UInt32(MemoryLayout<Float64>.size)
        if AudioObjectGetPropertyData(device, &a, 0, nil, &size, &rate) == noErr, rate > 0 { snap.rate = rate }

        a = Self.address(kAudioDevicePropertyAvailableNominalSampleRates)
        if AudioObjectGetPropertyDataSize(device, &a, 0, nil, &size) == noErr {
            var ranges = [AudioValueRange](repeating: AudioValueRange(), count: Int(size) / MemoryLayout<AudioValueRange>.size)
            if AudioObjectGetPropertyData(device, &a, 0, nil, &size, &ranges) == noErr {
                snap.rates = Array(Set(ranges.map(\.mMinimum))).sorted()
            }
        }

        a = Self.address(kAudioDevicePropertyClockSource)
        var src = UInt32(0); size = 4
        if AudioObjectGetPropertyData(device, &a, 0, nil, &size, &src) == noErr { snap.source = src }

        a = Self.address(kAudioDevicePropertyClockSources)
        if AudioObjectGetPropertyDataSize(device, &a, 0, nil, &size) == noErr {
            var ids = [UInt32](repeating: 0, count: Int(size) / 4)
            if AudioObjectGetPropertyData(device, &a, 0, nil, &size, &ids) == noErr {
                snap.sources = ids.map { ($0, Self.sourceName(device, $0) ?? "Source \($0)") }
            }
        }
        onChange(snap)
    }

    private static func sourceName(_ dev: AudioObjectID, _ id: UInt32) -> String? {
        var inID = id
        var name: Unmanaged<CFString>?
        var a = address(kAudioDevicePropertyClockSourceNameForIDCFString)
        var size = UInt32(MemoryLayout<AudioValueTranslation>.size)
        // The pointers are only valid inside these closures, so the call happens there too.
        let status = withUnsafeMutablePointer(to: &inID) { inPtr in
            withUnsafeMutablePointer(to: &name) { outPtr in
                var t = AudioValueTranslation(mInputData: inPtr, mInputDataSize: 4, mOutputData: outPtr,
                                              mOutputDataSize: UInt32(MemoryLayout<Unmanaged<CFString>?>.size))
                return AudioObjectGetPropertyData(dev, &a, 0, nil, &size, &t)
            }
        }
        guard status == noErr else { return nil }
        return name?.takeRetainedValue() as String?
    }

    private static func findScarlett() -> AudioObjectID {
        let system = AudioObjectID(kAudioObjectSystemObject)
        var a = address(kAudioHardwarePropertyDevices)
        var size = UInt32(0)
        guard AudioObjectGetPropertyDataSize(system, &a, 0, nil, &size) == noErr else { return AudioObjectID(kAudioObjectUnknown) }
        var ids = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(system, &a, 0, nil, &size, &ids) == noErr else { return AudioObjectID(kAudioObjectUnknown) }
        var ua = address(kAudioDevicePropertyDeviceUID)
        for id in ids {
            var uid: Unmanaged<CFString>?
            var us = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
            guard AudioObjectGetPropertyData(id, &ua, 0, nil, &us, &uid) == noErr,
                  let s = uid?.takeRetainedValue() as String? else { continue }
            if s.hasPrefix("AppleUSBAudioEngine:Focusrite:Scarlett") { return id }
        }
        return AudioObjectID(kAudioObjectUnknown)
    }
}

/// "48", "44.1", "96".
func kHzText(_ hz: Double) -> String {
    let k = hz / 1000
    return k == k.rounded() ? String(Int(k)) : String(format: "%.1f", k)
}
