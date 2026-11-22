//
//  MixerState.swift
//  ScarlettKit
//
//  A snapshot of a device's mixer state, read in one pass.
//  A nil value means that read failed.
//

import Foundation

public struct ChannelState: Sendable, Equatable {
    public var volume: Double?   // dB
    public var muted: Bool?
    public var source: Source?
}

public struct OutputPairState: Sendable, Equatable, Identifiable {
    public let index: Int        // pair k covers buses 2k+1, 2k+2
    public let name: String
    public var left: ChannelState
    public var right: ChannelState
    public var id: Int { index }
}

public struct MixerInputState: Sendable, Equatable, Identifiable {
    public let index: Int        // 0-based
    public var source: Source?
    public var gains: [Double?]  // dB, one per mix
    public var id: Int { index }
}

public struct MixerState: Sendable, Equatable {
    public let model: ScarlettModel
    public var clockSource: ClockSource?
    public var sampleRate: UInt32?
    public var syncLocked: Bool?
    public var masterVolume: Double?
    public var masterMuted: Bool?
    public var padOn: Bool?
    public var outputs: [OutputPairState]
    public var capture: [Source?]
    public var inputs: [MixerInputState]
}

extension ScarlettDevice {
    /// Reads the whole mixer state. Read-only.
    /// `readPad`: the −20 dB pad (entity 0x14) is read only when asked; Focusrite's software reads it once per connection.
    public func readState(readPad: Bool = false) -> MixerState {
        let m = model
        func channel(bus: Int) -> ChannelState {
            ChannelState(volume: try? outputVolume(bus: bus),
                         muted: try? outputMuted(bus: bus),
                         source: try? outputSource(bus - 1))
        }
        return MixerState(
            model: m,
            clockSource: (try? clockSource()) ?? nil,
            sampleRate: try? sampleRate(),
            syncLocked: try? syncLocked(),
            masterVolume: try? outputVolume(bus: 0),
            masterMuted: try? outputMuted(bus: 0),
            padOn: readPad ? (try? padOn()) : nil,
            outputs: m.outputPairs.enumerated().map { k, name in
                OutputPairState(index: k, name: name, left: channel(bus: 2 * k + 1), right: channel(bus: 2 * k + 2))
            },
            capture: (0..<m.captureChannels).map { try? captureSource($0) },
            inputs: (0..<m.mixerInputs).map { i in
                MixerInputState(index: i,
                                source: try? mixerInputSource(i),
                                gains: (0..<m.mixes).map { try? mixerGain(input: i, mix: $0) })
            })
    }

    /// Opens the first supported device, reads its state and closes it.
    public static func readFirstState() throws -> MixerState {
        let device = try openFirst()
        defer { device.close() }
        return device.readState()
    }
}

extension ScarlettModel {
    /// Mix names: "A", "B", …
    public var mixNames: [String] {
        (0..<mixes).map { String(Character(UnicodeScalar(UInt8(65 + $0)))) }
    }
}
