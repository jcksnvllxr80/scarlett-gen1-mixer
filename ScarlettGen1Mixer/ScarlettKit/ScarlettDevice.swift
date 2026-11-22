//
//  ScarlettDevice.swift
//  ScarlettKit
//
//  USB access to a connected Scarlett through IOUSBHost.
//  Request format: docs/protocol.md, "Request format".
//

import Foundation
import IOKit
import IOUSBHost

public enum ScarlettError: Error, CustomStringConvertible {
    case notFound
    case openFailed(Error)
    case requestFailed(entity: UInt8, wValue: UInt16, Error)
    case shortRead(expected: Int, got: Int)

    public var description: String {
        switch self {
        case .notFound:
            "No supported Scarlett found."
        case .openFailed(let e):
            "Couldn't open the device (is another mixer app using it?): \(e.localizedDescription)"
        case .requestFailed(let entity, let wValue, let e):
            String(format: "Request to entity 0x%02x wValue 0x%04x failed: ", entity, wValue) + e.localizedDescription
        case .shortRead(let expected, let got):
            "Expected \(expected) bytes, got \(got)."
        }
    }
}

/// A connected device found by `ScarlettDevice.find()`.
public struct ScarlettDeviceInfo: Sendable {
    public let model: ScarlettModel
    public let locationID: UInt32
}

/// An open connection to a Scarlett. Only one app can hold it at a time.
/// Call `close()` when done.
public final class ScarlettDevice {
    public let model: ScarlettModel
    private let usb: IOUSBHostDevice

    /// Interface number of the audio-control interface (low byte of wIndex).
    private let controlInterface: UInt16 = 0

    enum Request: UInt8 {
        case cur = 0x01  // UAC2_CS_CUR
        case mem = 0x03  // UAC2_CS_MEM
    }

    /// Lists supported Scarlett devices currently connected.
    public static func find() -> [ScarlettDeviceInfo] {
        var result: [ScarlettDeviceInfo] = []
        for model in ScarlettModel.allCases {
            forEachService(model: model) { service in
                result.append(ScarlettDeviceInfo(model: model, locationID: locationID(of: service) ?? 0))
            }
        }
        return result
    }

    /// Opens the first supported Scarlett found.
    public static func openFirst() throws -> ScarlettDevice {
        for model in ScarlettModel.allCases {
            var service: io_service_t = 0
            forEachService(model: model) { s in
                if service == 0 { service = s; IOObjectRetain(s) }
            }
            if service != 0 {
                defer { IOObjectRelease(service) }
                return try ScarlettDevice(service: service, model: model)
            }
        }
        throw ScarlettError.notFound
    }

    init(service: io_service_t, model: ScarlettModel) throws {
        self.model = model
        do {
            usb = try IOUSBHostDevice(__ioService: service, options: [], queue: nil, interestHandler: nil)
        } catch {
            throw ScarlettError.openFailed(error)
        }
    }

    public func close() { usb.destroy() }

    // MARK: Reads

    /// Reads up to `length` bytes. Some controls answer with fewer bytes than the
    /// Linux driver asks for (see docs/protocol.md, "Observed on the 18i20"),
    /// so replies of at least `minimumLength` bytes are accepted.
    func read(_ request: Request, entity: UInt8, wValue: UInt16, length: Int, minimumLength: Int? = nil) throws -> [UInt8] {
        let setup = IOUSBDeviceRequest(
            bmRequestType: 0xA1,  // device-to-host, class, interface
            bRequest: request.rawValue,
            wValue: wValue,
            wIndex: UInt16(entity) << 8 | controlInterface,
            wLength: UInt16(length))
        let data = NSMutableData(length: length)!
        var transferred = 0
        do {
            try usb.__send(setup, data: data, bytesTransferred: &transferred, completionTimeout: 1.0)
        } catch {
            throw ScarlettError.requestFailed(entity: entity, wValue: wValue, error)
        }
        let minimum = minimumLength ?? length
        guard transferred >= minimum else { throw ScarlettError.shortRead(expected: minimum, got: transferred) }
        return Array([UInt8](data as Data).prefix(transferred))
    }

    /// Reads a signed 16-bit value. A 1-byte reply is read as a signed byte.
    func readS16(_ request: Request = .cur, entity: UInt8, wValue: UInt16) throws -> Int16 {
        let b = try read(request, entity: entity, wValue: wValue, length: 2, minimumLength: 1)
        if b.count == 1 { return Int16(Int8(bitPattern: b[0])) }
        return Int16(bitPattern: UInt16(b[0]) | UInt16(b[1]) << 8)
    }

    // MARK: Writes

    /// A control write, described before it's sent (for review and logging).
    public struct WriteRequest: CustomStringConvertible, Sendable {
        public let bRequest: UInt8
        public let entity: UInt8
        public let wValue: UInt16
        public let data: [UInt8]
        public var wIndex: UInt16 { UInt16(entity) << 8 }
        public var description: String {
            String(format: "bmRequestType 0x21, bRequest 0x%02x, wValue 0x%04x, wIndex 0x%04x, data %@",
                   bRequest, wValue, wIndex, data.map { String(format: "%02x", $0) }.joined(separator: " "))
        }
    }

    /// Sends a write. Only requests documented in docs/protocol.md may be sent.
    public func send(_ w: WriteRequest) throws {
        let setup = IOUSBDeviceRequest(
            bmRequestType: 0x21,  // host-to-device, class, interface
            bRequest: w.bRequest, wValue: w.wValue, wIndex: w.wIndex, wLength: UInt16(w.data.count))
        let data = NSMutableData(bytes: w.data, length: w.data.count)
        var transferred = 0
        do {
            try usb.__send(setup, data: data, bytesTransferred: &transferred, completionTimeout: 1.0)
        } catch {
            throw ScarlettError.requestFailed(entity: w.entity, wValue: w.wValue, error)
        }
    }

    /// Mixer gain write for input i → mix m (both 0-based). Uses `0x0100 | node`,
    /// as Focusrite's software does (docs/protocol.md, "Monitor section").
    public static func mixerGainRequest(input i: Int, mix m: Int, dB: Double) -> WriteRequest {
        let raw = UInt16(bitPattern: Decibels.toRaw(dB))
        return WriteRequest(bRequest: Request.cur.rawValue, entity: 0x3c,
                            wValue: 0x0100 | UInt16(i << 3 | (m & 0x07)),
                            data: [UInt8(raw & 0xff), UInt8(raw >> 8)])
    }

    // MARK: Controls (docs/protocol.md, "Controls")

    /// Output bus volume in dB. Bus 0 = master, 1… = individual outputs.
    public func outputVolume(bus: Int) throws -> Double {
        Decibels.fromRaw(try readS16(entity: 0x0a, wValue: 0x0200 + UInt16(bus)))
    }

    /// Output bus mute. Bus 0 = master. Read as 1 byte: a 2-byte read returns
    /// a meaningless second byte on the 18i20.
    public func outputMuted(bus: Int) throws -> Bool {
        try read(.cur, entity: 0x0a, wValue: 0x0100 + UInt16(bus), length: 1)[0] != 0
    }

    /// Source feeding output n (0-based, = bus − 1).
    public func outputSource(_ n: Int) throws -> Source {
        Source(raw: try readS16(entity: 0x33, wValue: UInt16(n)), model: model)
    }

    /// Source recorded on capture channel c (0-based).
    public func captureSource(_ c: Int) throws -> Source {
        Source(raw: try readS16(entity: 0x34, wValue: UInt16(c)), model: model)
    }

    /// Source feeding mixer input i (0-based).
    public func mixerInputSource(_ i: Int) throws -> Source {
        Source(raw: try readS16(entity: 0x32, wValue: 0x0600 + UInt16(i)), model: model)
    }

    /// Gain in dB from mixer input i to mix m (both 0-based).
    public func mixerGain(input i: Int, mix m: Int) throws -> Double {
        Decibels.fromRaw(try readS16(entity: 0x3c, wValue: UInt16(i << 3 | (m & 0x07))))
    }

    public func clockSource() throws -> ClockSource? {
        ClockSource(rawValue: try read(.cur, entity: 0x28, wValue: 0x0100, length: 1)[0])
    }

    /// Sample rate in Hz (read only here; on macOS, change it through CoreAudio).
    public func sampleRate() throws -> UInt32 {
        let b = try read(.cur, entity: 0x29, wValue: 0x0100, length: 4)
        return UInt32(b[0]) | UInt32(b[1]) << 8 | UInt32(b[2]) << 16 | UInt32(b[3]) << 24
    }

    public func syncLocked() throws -> Bool {
        try read(.mem, entity: 0x3c, wValue: 0x0002, length: 1)[0] == 1
    }

    // MARK: Helpers

    private static func forEachService(model: ScarlettModel, _ body: (io_service_t) -> Void) {
        let matching = IOUSBHostDevice.__createMatchingDictionary(
            withVendorID: NSNumber(value: focusriteVendorID), productID: NSNumber(value: model.productID),
            bcdDevice: nil, deviceClass: nil, deviceSubclass: nil, deviceProtocol: nil,
            speed: nil, productIDArray: nil).takeRetainedValue()
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else { return }
        defer { IOObjectRelease(iterator) }
        while case let service = IOIteratorNext(iterator), service != 0 {
            body(service)
            IOObjectRelease(service)
        }
    }

    private static func locationID(of service: io_service_t) -> UInt32? {
        guard let v = IORegistryEntryCreateCFProperty(service, "locationID" as CFString, kCFAllocatorDefault, 0)?
            .takeRetainedValue() as? NSNumber else { return nil }
        return v.uint32Value
    }
}

// MARK: - More writes (formats from Focusrite's own traffic; docs/protocol.md)

extension Source {
    /// Raw value for writing. Off is written as the value the 18i20 reports
    /// for unused outputs (first value past the last mix), as Focusrite's software does.
    public func raw(model: ScarlettModel) -> Int16 {
        let o = model.sourceOffsets
        switch self {
        case .off: return Int16(o.mix + model.mixes)
        case .daw(let n): return Int16(o.pcm + n - 1)
        case .analog(let n): return Int16(o.analog + n - 1)
        case .spdif(let n): return Int16(o.spdif + n - 1)
        case .adat(let n): return Int16(o.adat + n - 1)
        case .mix(let n): return Int16(o.mix + n)
        case .unknown(let r): return r
        }
    }

    /// Every source a given model offers, in menu order.
    public static func all(model: ScarlettModel, includeMixes: Bool) -> [Source] {
        let o = model.sourceOffsets
        var list: [Source] = [.off]
        list += (1...max(1, o.analog - o.pcm)).map { .daw($0) }
        list += (1...max(1, o.spdif - o.analog)).map { .analog($0) }
        if o.adat > o.spdif { list += (1...(o.adat - o.spdif)).map { .spdif($0) } }
        if o.mix > o.adat { list += (1...(o.mix - o.adat)).map { .adat($0) } }
        if includeMixes { list += (0..<model.mixes).map { .mix($0) } }
        return list
    }
}

extension ScarlettDevice {
    private static func s16(_ v: Int16) -> [UInt8] {
        let u = UInt16(bitPattern: v)
        return [UInt8(u & 0xff), UInt8(u >> 8)]
    }

    public static func mixerInputSourceRequest(input i: Int, source: Source, model: ScarlettModel) -> WriteRequest {
        WriteRequest(bRequest: 0x01, entity: 0x32, wValue: 0x0600 + UInt16(i), data: s16(source.raw(model: model)))
    }
    public static func outputSourceRequest(output n: Int, source: Source, model: ScarlettModel) -> WriteRequest {
        WriteRequest(bRequest: 0x01, entity: 0x33, wValue: UInt16(n), data: s16(source.raw(model: model)))
    }
    public static func captureSourceRequest(channel c: Int, source: Source, model: ScarlettModel) -> WriteRequest {
        WriteRequest(bRequest: 0x01, entity: 0x34, wValue: UInt16(c), data: s16(source.raw(model: model)))
    }
    /// Output bus mute (bus 1… ; 0 = master).
    public static func outputMuteRequest(bus: Int, muted: Bool) -> WriteRequest {
        WriteRequest(bRequest: 0x01, entity: 0x0a, wValue: 0x0100 + UInt16(bus), data: s16(muted ? 1 : 0))
    }
    /// Monitor Dim (MEM 0x3c/0x0006) and Mute (MEM 0x3c/0x0005): 1-byte, write-only.
    public static func monitorDimRequest(_ on: Bool) -> WriteRequest {
        WriteRequest(bRequest: 0x03, entity: 0x3c, wValue: 0x0006, data: [on ? 1 : 0])
    }
    public static func monitorMuteRequest(_ on: Bool) -> WriteRequest {
        WriteRequest(bRequest: 0x03, entity: 0x3c, wValue: 0x0005, data: [on ? 1 : 0])
    }
    /// Mono sum for line-output pair p (1…5): entity 0x14, 1 byte, write-only.
    public static func monoRequest(pair p: Int, _ on: Bool) -> WriteRequest {
        WriteRequest(bRequest: 0x01, entity: 0x14, wValue: 0x0a00 + UInt16(p), data: [on ? 1 : 0])
    }
    /// −20 dB pad on Monitor 1/2: entity 0x14/0x0801, 1 byte (readable).
    public static func padRequest(_ on: Bool) -> WriteRequest {
        WriteRequest(bRequest: 0x01, entity: 0x14, wValue: 0x0801, data: [on ? 1 : 0])
    }
    /// Reads the −20 dB pad (1 byte), as Focusrite's software does at connect. 18i20 only.
    public func padOn() throws -> Bool {
        guard model == .scarlett18i20 else { throw ScarlettError.notFound }
        return try read(.cur, entity: 0x14, wValue: 0x0801, length: 1)[0] != 0
    }
}

extension ScarlettDevice {
    /// Save the current settings to the interface's memory (survives power cycles).
    /// Linux driver header comment (mixer_scarlett.c lines 73–74): MEM 0x3c, wValue 0x005a, data 0xA5.
    public static func saveToHardwareRequest() -> WriteRequest {
        WriteRequest(bRequest: 0x03, entity: 0x3c, wValue: 0x005a, data: [0xA5])
    }
}
