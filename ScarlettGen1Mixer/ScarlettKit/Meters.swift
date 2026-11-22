//
//  Meters.swift
//  ScarlettKit
//
//  Peak meters: MEM reads on entity 0x3c (Linux header comment, lines 67–71).
//  Sizes confirmed on the user's 18i20 (docs/protocol.md). Other models aren't
//  confirmed yet, so meters are only enabled for the 18i20.
//

import Foundation

public struct MeterLayout: Sendable, Equatable {
    public let inputs: Int   // MEM 0x3c/0x0000
    public let mixes: Int    // MEM 0x3c/0x0001
    public let daw: Int      // MEM 0x3c/0x0003
}

public struct Meters: Sendable, Equatable {
    public var inputs: [UInt16]
    public var mixes: [UInt16]
    public var daw: [UInt16]
    /// Hardware monitor knob level in dB (−byte0 of MEM 0x3c/0x0004), or nil if not read.
    public var monitorKnobDB: Double?
    /// The knob slot's raw 4 bytes (bytes 1–3 not yet understood).
    public var monitorKnobRaw: [UInt8] = []

    /// Assumes raw values are linear peak amplitude with full scale = 0xFFFF.
    /// Not confirmed yet: quiet inputs read 1–5, which fits a noise floor of about −85 to −95 dBFS.
    public static func dBFS(_ raw: UInt16) -> Double {
        raw == 0 ? -.infinity : 20 * log10(Double(raw) / 65535)
    }
}

extension ScarlettModel {
    /// Meter sizes, or nil if not confirmed for this model.
    public var meterLayout: MeterLayout? {
        switch self {
        case .scarlett18i20: MeterLayout(inputs: 18, mixes: 8, daw: 20)
        default: nil
        }
    }

    /// Names for the input meters. The order is assumed to match the capture
    /// channel order (analog, S/PDIF, ADAT). Not confirmed yet.
    public var inputMeterNames: [String] {
        switch self {
        case .scarlett18i20:
            (1...8).map { "Analog \($0)" } + (1...2).map { "S/PDIF \($0)" } + (1...8).map { "ADAT \($0)" }
        default: []
        }
    }
}

extension ScarlettDevice {
    /// Reads all peak meters, or returns nil if meters aren't confirmed for this model.
    public func readMeters() throws -> Meters? {
        guard let layout = model.meterLayout else { return nil }
        func block(_ wValue: UInt16, _ count: Int) throws -> [UInt16] {
            let b = try read(.mem, entity: 0x3c, wValue: wValue, length: count * 2)
            return (0..<count).map { UInt16(b[2 * $0]) | UInt16(b[2 * $0 + 1]) << 8 }
        }
        var meters = Meters(inputs: try block(0x0000, layout.inputs),
                            mixes: try block(0x0001, layout.mixes),
                            daw: try block(0x0003, layout.daw))
        if let knob = try? readMonitorKnob() {
            meters.monitorKnobRaw = knob
            meters.monitorKnobDB = -Double(knob[0])
        }
        return meters
    }

    /// Hardware monitor knob: MEM 0x3c/0x0004, exactly 4 bytes (docs/protocol.md).
    /// Only confirmed on the 18i20. Never read neighbouring slots: 0x0005 hangs the device.
    public func readMonitorKnob() throws -> [UInt8] {
        guard model == .scarlett18i20 else { throw ScarlettError.notFound }
        return try read(.mem, entity: 0x3c, wValue: 0x0004, length: 4)
    }
}
