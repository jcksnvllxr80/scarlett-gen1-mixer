//
//  ScarlettKit.swift
//  ScarlettKit
//
//  Device and protocol support for 1st-gen Focusrite Scarlett interfaces.
//  Model data comes from the Linux driver `sound/usb/mixer_scarlett.c`.
//  See docs/protocol.md.
//

import Foundation

/// Focusrite's USB vendor ID.
public let focusriteVendorID: UInt16 = 0x1235

/// Where each kind of source starts in a model's source list
/// (Linux `scarlett_mixer_elem_enum_info.offsets`).
public struct SourceOffsets: Sendable, Equatable {
    public let pcm, analog, spdif, adat, mix: Int
}

/// 1st-gen Scarlett models with an internal mixer.
/// Product IDs and tables from the Linux driver.
public enum ScarlettModel: UInt16, CaseIterable, Sendable {
    case scarlett8i6 = 0x8002
    case scarlett18i6 = 0x8004
    case scarlett18i20 = 0x800c
    case scarlett6i6 = 0x8012
    case scarlett18i8 = 0x8014

    public var productID: UInt16 { rawValue }

    public var name: String {
        switch self {
        case .scarlett6i6: "Scarlett 6i6"
        case .scarlett8i6: "Scarlett 8i6"
        case .scarlett18i6: "Scarlett 18i6"
        case .scarlett18i8: "Scarlett 18i8"
        case .scarlett18i20: "Scarlett 18i20"
        }
    }

    /// Returns the model for a USB vendor and product ID, or nil if unsupported.
    public init?(vendorID: UInt16, productID: UInt16) {
        guard vendorID == focusriteVendorID else { return nil }
        self.init(rawValue: productID)
    }

    /// Number of mixer inputs (`matrix_in`).
    public var mixerInputs: Int { 18 }

    /// Number of mixes, A… (`matrix_out`).
    public var mixes: Int {
        switch self {
        case .scarlett6i6, .scarlett18i8, .scarlett18i20: 8
        case .scarlett8i6, .scarlett18i6: 6
        }
    }

    /// Number of channels recorded to the computer (`input_len`).
    public var captureChannels: Int {
        switch self {
        case .scarlett6i6: 6
        case .scarlett8i6: 8
        case .scarlett18i6, .scarlett18i8, .scarlett18i20: 18
        }
    }

    /// Stereo output pairs, in bus order (Linux `controls` of type SCARLETT_OUTPUTS).
    /// Pair k covers output buses 2k+1 and 2k+2.
    public var outputPairs: [String] {
        switch self {
        case .scarlett6i6, .scarlett8i6, .scarlett18i6: ["Monitor", "Headphone", "S/PDIF"]
        case .scarlett18i8: ["Monitor", "Headphone 1", "Headphone 2", "S/PDIF"]
        case .scarlett18i20:
            ["Monitor", "Line 3/4", "Line 5/6", "Line 7/8", "Line 9/10",
             "S/PDIF", "ADAT 1/2", "ADAT 3/4", "ADAT 5/6", "ADAT 7/8"]
        }
    }

    public var sourceOffsets: SourceOffsets {
        switch self {
        case .scarlett6i6, .scarlett8i6: SourceOffsets(pcm: 0, analog: 12, spdif: 16, adat: 18, mix: 18)
        case .scarlett18i6: SourceOffsets(pcm: 0, analog: 6, spdif: 14, adat: 16, mix: 24)
        case .scarlett18i8: SourceOffsets(pcm: 0, analog: 8, spdif: 16, adat: 18, mix: 26)
        case .scarlett18i20: SourceOffsets(pcm: 0, analog: 20, spdif: 28, adat: 30, mix: 38)
        }
    }
}

/// A signal source for an output, a capture channel or a mixer input.
public enum Source: Hashable, Sendable, CustomStringConvertible {
    case off
    case daw(Int)       // computer playback channel, 1-based
    case analog(Int)
    case spdif(Int)
    case adat(Int)
    case mix(Int)       // 0 = Mix A
    case unknown(Int16)

    /// Decodes a raw source value. Linux: list item = raw + 1, named by
    /// `scarlett_generate_name` (mixer_scarlett.c lines 601–616).
    public init(raw: Int16, model: ScarlettModel) {
        let item = Int(raw) + 1
        let o = model.sourceOffsets
        let mixCount = model.mixes
        // Linux writes -1 for Off. The 18i20 reports unused outputs as the first
        // value past the last mix (46), so that's read as Off too (observed,
        // not yet confirmed — docs/protocol.md).
        if Int(raw) == o.mix + mixCount { self = .off; return }
        switch item {
        case 0: self = .off
        case (o.mix + 1)...(o.mix + mixCount): self = .mix(item - o.mix - 1)
        case _ where item > o.mix: self = .unknown(raw)
        case _ where item > o.adat: self = .adat(item - o.adat)
        case _ where item > o.spdif: self = .spdif(item - o.spdif)
        case _ where item > o.analog: self = .analog(item - o.analog)
        case _ where item > o.pcm: self = .daw(item - o.pcm)
        default: self = .unknown(raw)
        }
    }

    public var description: String {
        switch self {
        case .off: "Off"
        case .daw(let n): "DAW \(n)"
        case .analog(let n): "Analog \(n)"
        case .spdif(let n): "S/PDIF \(n)"
        case .adat(let n): "ADAT \(n)"
        case .mix(let n): "Mix \(Character(UnicodeScalar(UInt8(65 + n))))"
        case .unknown(let raw): "Unknown (\(raw))"
        }
    }
}

/// Gains and volumes are dB × 256 in a signed 16-bit value (−128 to +6 dB).
public enum Decibels {
    public static func fromRaw(_ raw: Int16) -> Double { Double(raw) / 256 }
    public static func toRaw(_ dB: Double) -> Int16 {
        Int16((min(max(dB, -128), 6) * 256).rounded())
    }
}

/// Clock source values (Linux `opt_clock`, start = 1).
public enum ClockSource: UInt8, Sendable {
    case `internal` = 1, spdif = 2, adat = 3
}
