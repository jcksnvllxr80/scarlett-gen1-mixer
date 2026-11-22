//
//  main.swift
//  scarlett
//
//  Command-line tool for testing ScarlettKit against real hardware.
//  All commands here are read-only.
//

import Foundation
import ScarlettKit

func usage() -> Never {
    print("""
    usage: scarlett <command>
      models   list supported models
      info     list connected devices
      dump     read and print the device's current mixer state (read-only)
      meters [seconds]  print the DAW 1/2 and Mix A/B peak meters in dBFS once a second (read-only; default 20 s)
      set-gain <input 1-18> <mix A-H> <dB|-inf> [--yes]
               show the mixer-gain write; sends it only with --yes, then reads it back
    """)
    exit(2)
}

func dB(_ v: Double?) -> String {
    guard let v else { return " error" }
    return v <= -128 ? "  -inf" : String(format: "%+6.1f", v)
}
func text<T>(_ v: T?) -> String { v.map { "\($0)" } ?? "error" }
func mute(_ v: Bool?) -> String { v.map { $0 ? "M" : "-" } ?? "?" }
func pad(_ s: String, _ n: Int) -> String { s.padding(toLength: n, withPad: " ", startingAt: 0) }

func dump() throws {
    let s = try ScarlettDevice.readFirstState()
    let m = s.model
    print("\(m.name)\n")

    print("Clock")
    print("  source       ", text(s.clockSource))
    print("  sample rate  ", s.sampleRate.map { "\($0) Hz" } ?? "error")
    print("  sync         ", s.syncLocked.map { $0 ? "locked" : "not locked" } ?? "error")

    print("\nOutputs                volume L/R      mute L/R     source L / R")
    print("  Master (all)       ", dB(s.masterVolume), "         ", s.masterMuted.map { $0 ? "muted" : "on" } ?? "error")
    for o in s.outputs {
        print("  " + pad(o.name, 18), dB(o.left.volume) + " " + dB(o.right.volume), "   ",
              mute(o.left.muted) + " " + mute(o.right.muted), "        ",
              text(o.left.source) + " / " + text(o.right.source))
    }

    print("\nRecorded to computer")
    for (c, src) in s.capture.enumerated() {
        print(String(format: "  channel %2d  ", c + 1) + text(src))
    }

    print("\nMixer (gain in dB per mix)")
    print("  input  source        " + m.mixNames.map { "     \($0)" }.joined())
    for i in s.inputs {
        print(String(format: "  %2d     ", i.index + 1) + pad(text(i.source), 13) + " " + i.gains.map(dB).joined())
    }
}

let args = CommandLine.arguments.dropFirst()
switch args.first {
case "models":
    for model in ScarlettModel.allCases {
        print(String(format: "%@  %04x:%04x", model.name, focusriteVendorID, model.productID))
    }
case "info":
    let found = ScarlettDevice.find()
    if found.isEmpty { print("No supported Scarlett connected.") }
    for d in found { print(String(format: "%@  location 0x%08x", d.model.name, d.locationID)) }
case "dump":
    do { try dump() } catch { print("error: \(error)"); exit(1) }
case "meters":
    let seconds = Int(args.dropFirst().first ?? "") ?? 20
    func f(_ raw: UInt16?) -> String {
        guard let raw else { return "     ?" }
        let d = Meters.dBFS(raw)
        return d.isFinite ? String(format: "%+6.1f", d) : "  -inf"
    }
    do {
        let dev = try ScarlettDevice.openFirst()
        defer { dev.close() }
        print("time   DAW1    DAW2    MixA    MixB   (dBFS, peak since last read)")
        for t in 0..<seconds {
            // Uses only the documented meter reads (MEM 0x3c 0x0000/1/3), like the app
            guard let m = try dev.readMeters() else { print("meters not supported for this model"); exit(1) }
            print(String(format: "%3ds  ", t) + [f(m.daw.first), f(m.daw.dropFirst().first), f(m.mixes.first), f(m.mixes.dropFirst().first)].joined(separator: "  "))
            Thread.sleep(forTimeInterval: 1)
        }
    } catch { print("error: \(error)"); exit(1) }
case "set-gain":
    let a = Array(args.dropFirst())
    guard a.count >= 3, let input = Int(a[0]), (1...18).contains(input),
          let mixChar = a[1].uppercased().first, let mix = "ABCDEFGH".firstIndex(of: mixChar)
    else { usage() }
    let m = "ABCDEFGH".distance(from: "ABCDEFGH".startIndex, to: mix)
    let dBValue = a[2].lowercased() == "-inf" ? -128 : Double(a[2])
    guard let dBValue else { usage() }
    let req = ScarlettDevice.mixerGainRequest(input: input - 1, mix: m, dB: dBValue)
    print("Mixer gain, input \(input) → Mix \(mixChar) = \(dB(dBValue)) dB")
    print("  request: \(req)")
    guard a.contains("--yes") else { print("  not sent (add --yes to send)"); exit(0) }
    do {
        let dev = try ScarlettDevice.openFirst()
        defer { dev.close() }
        let before = try dev.mixerGain(input: input - 1, mix: m)
        try dev.send(req)
        let after = try dev.mixerGain(input: input - 1, mix: m)
        print("  sent. read back: before \(dB(before)) dB, after \(dB(after)) dB")
    } catch { print("error: \(error)"); exit(1) }
default:
    usage()
}
