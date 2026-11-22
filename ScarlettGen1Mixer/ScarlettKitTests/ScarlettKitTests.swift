//
//  ScarlettKitTests.swift
//  ScarlettKitTests
//

import Foundation
import Testing
@testable import ScarlettKit

struct ScarlettModelTests {

    @Test func recognizes18i20() {
        #expect(ScarlettModel(vendorID: 0x1235, productID: 0x800c) == .scarlett18i20)
    }

    @Test func rejectsOtherVendors() {
        #expect(ScarlettModel(vendorID: 0x05ac, productID: 0x800c) == nil)
    }

    @Test func rejectsUnknownProducts() {
        #expect(ScarlettModel(vendorID: 0x1235, productID: 0x8010) == nil)
    }

    @Test func productIDsAreUnique() {
        let ids = ScarlettModel.allCases.map(\.productID)
        #expect(Set(ids).count == ids.count)
    }

    @Test func outputPairsMatchLinuxOutputCounts() {
        // Linux output_len: 6i6 6, 8i6 6, 18i6 6, 18i8 8, 18i20 20.
        #expect(ScarlettModel.scarlett18i20.outputPairs.count * 2 == 20)
        #expect(ScarlettModel.scarlett18i8.outputPairs.count * 2 == 8)
        #expect(ScarlettModel.scarlett6i6.outputPairs.count * 2 == 6)
    }
}

struct SourceTests {
    let m = ScarlettModel.scarlett18i20

    // Raw values from the Linux 18i20 table (docs/protocol.md).
    @Test func decodes18i20Ranges() {
        #expect(Source(raw: -1, model: m) == .off)
        #expect(Source(raw: 0, model: m) == .daw(1))
        #expect(Source(raw: 19, model: m) == .daw(20))
        #expect(Source(raw: 20, model: m) == .analog(1))
        #expect(Source(raw: 27, model: m) == .analog(8))
        #expect(Source(raw: 28, model: m) == .spdif(1))
        #expect(Source(raw: 30, model: m) == .adat(1))
        #expect(Source(raw: 37, model: m) == .adat(8))
        #expect(Source(raw: 38, model: m) == .mix(0))
        #expect(Source(raw: 45, model: m) == .mix(7))
    }

    // Observed on the user's 18i20 for unused outputs.
    @Test func decodesObservedOffValue() {
        #expect(Source(raw: 46, model: m) == .off)
    }

    @Test func flagsOutOfRangeValues() {
        #expect(Source(raw: 47, model: m) == .unknown(47))
    }

    @Test func names() {
        #expect(Source.mix(0).description == "Mix A")
        #expect(Source.analog(3).description == "Analog 3")
    }
}

struct DecibelTests {
    @Test func linuxEncoding() {
        #expect(Decibels.fromRaw(0) == 0)
        #expect(Decibels.fromRaw(Int16(bitPattern: 0xF600)) == -10)
        #expect(Decibels.fromRaw(0x0600) == 6)
        #expect(Decibels.fromRaw(Int16.min) == -128)
    }

    @Test func roundTripAndClamp() {
        #expect(Decibels.toRaw(-10) == Int16(bitPattern: 0xF600))
        #expect(Decibels.toRaw(20) == 0x0600)   // clamped to +6 dB
        #expect(Decibels.toRaw(-200) == Int16.min)
    }
}

struct SourceEncodingTests {
    let m = ScarlettModel.scarlett18i20

    @Test func rawRoundTrip() {
        for s in Source.all(model: m, includeMixes: true) {
            #expect(Source(raw: s.raw(model: m), model: m) == s, "round trip failed for \(s)")
        }
    }

    @Test func offIsWrittenAs46() {
        // Focusrite's software writes 0x2e for Off on the 18i20.
        #expect(Source.off.raw(model: m) == 46)
    }

    @Test func sourceListFor18i20() {
        let all = Source.all(model: m, includeMixes: true)
        #expect(all.count == 1 + 20 + 8 + 2 + 8 + 8)   // Off, DAW, Analog, S/PDIF, ADAT, Mixes
        #expect(!Source.all(model: m, includeMixes: false).contains(.mix(0)))
    }
}

struct WriteRequestTests {
    let m = ScarlettModel.scarlett18i20

    @Test func mixerGain() {
        // Confirmed on hardware: input 9 → Mix A at −60 dB = wValue 0x0140, data 00 c4.
        let r = ScarlettDevice.mixerGainRequest(input: 8, mix: 0, dB: -60)
        #expect(r.entity == 0x3c && r.bRequest == 0x01 && r.wValue == 0x0140 && r.data == [0x00, 0xc4])
        #expect(r.wIndex == 0x3c00)
        #expect(ScarlettDevice.mixerGainRequest(input: 8, mix: 0, dB: -200).data == [0x00, 0x80])
    }

    @Test func routing() {
        let out = ScarlettDevice.outputSourceRequest(output: 0, source: .mix(0), model: m)
        #expect(out.entity == 0x33 && out.wValue == 0x0000 && out.data == [0x26, 0x00])
        let cap = ScarlettDevice.captureSourceRequest(channel: 2, source: .analog(3), model: m)
        #expect(cap.entity == 0x34 && cap.wValue == 0x0002 && cap.data == [0x16, 0x00])
        let inp = ScarlettDevice.mixerInputSourceRequest(input: 17, source: .daw(2), model: m)
        #expect(inp.entity == 0x32 && inp.wValue == 0x0611 && inp.data == [0x01, 0x00])
    }

    @Test func monitorControls() {
        #expect(ScarlettDevice.outputMuteRequest(bus: 1, muted: true).data == [0x01, 0x00])
        let dim = ScarlettDevice.monitorDimRequest(true)
        #expect(dim.bRequest == 0x03 && dim.entity == 0x3c && dim.wValue == 0x0006 && dim.data == [1])
        let mute = ScarlettDevice.monitorMuteRequest(false)
        #expect(mute.bRequest == 0x03 && mute.wValue == 0x0005 && mute.data == [0])
        let mono = ScarlettDevice.monoRequest(pair: 3, true)
        #expect(mono.entity == 0x14 && mono.wValue == 0x0a03 && mono.data == [1])
        let pad = ScarlettDevice.padRequest(true)
        #expect(pad.entity == 0x14 && pad.wValue == 0x0801 && pad.data == [1])
    }

    @Test func neverTargetsChannelZeroOfEntity0x14() {
        // 0x14/0x0a00 hangs the 18i20. Mono pairs must be 1…5.
        for p in 1...5 { #expect(ScarlettDevice.monoRequest(pair: p, true).wValue != 0x0a00) }
    }
}

struct PanLawTests {
    @Test func centreIsMinus6PerSide() {
        let (l, r) = PanLaw.gains(level: 0, pan: 0)
        #expect(abs(l - -6.02) < 0.05 && abs(r - -6.02) < 0.05)
    }

    @Test func hardLeftSilencesRight() {
        let (l, r) = PanLaw.gains(level: 0, pan: -1)
        #expect(abs(l) < 0.01 && r == -128)
    }

    @Test func roundTrip() {
        for (level, pan) in [(0.0, 0.0), (-10.0, 0.5), (3.0, -0.25), (-30.0, 0.9)] {
            let (l, r) = PanLaw.gains(level: level, pan: pan)
            let (level2, pan2) = PanLaw.levelPan(l, r)
            #expect(abs(level2 - level) < 0.01 && abs(pan2 - pan) < 0.01)
        }
    }

    @Test func silence() {
        #expect(PanLaw.gains(level: -128, pan: 0) == (-128, -128))
        let (level, _) = PanLaw.levelPan(-128, -128)
        #expect(level == -128)
    }
}

struct SaveToHardwareTests {
    @Test func linuxDocumentedRequest() {
        let r = ScarlettDevice.saveToHardwareRequest()
        #expect(r.bRequest == 0x03 && r.entity == 0x3c && r.wValue == 0x005a && r.data == [0xA5])
    }
}

struct MarkdownHTMLTests {
    @Test func headingsGetGitHubAnchors() {
        #expect(MarkdownHTML.convert("## Setups (save and recall)").contains(#"<h2 id="setups-save-and-recall">"#))
        #expect(MarkdownHTML.slug("Example: a band on in-ears") == "example-a-band-on-in-ears")
    }

    @Test func inlineFormatting() {
        let h = MarkdownHTML.convert("**Bold** and `a < b` and [link](#x) and *it*")
        #expect(h.contains("<strong>Bold</strong>") && h.contains("<code>a &lt; b</code>"))
        #expect(h.contains(##"<a href="#x">link</a>"##) && h.contains("<em>it</em>"))
    }

    @Test func tablesListsAndCode() {
        let md = "| A | B |\n|---|---|\n| 1 | 2 |\n\n- one\n- two\n\n1. first\n2. second\n\n```\nx < y\n```"
        let h = MarkdownHTML.convert(md)
        #expect(h.contains("<th>A</th>") && h.contains("<td>2</td>"))
        #expect(h.contains("<ul><li>one</li><li>two</li></ul>"))
        #expect(h.contains("<ol><li>first</li><li>second</li></ol>"))
        #expect(h.contains("<pre><code>x &lt; y</code></pre>"))
    }

    @Test func bundledGuideMatchesDocs() throws {
        // The app bundles a copy of docs/user-guide.md (scripts/sync-guide.sh). Keep them identical.
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let docs = try String(contentsOf: root.appendingPathComponent("docs/user-guide.md"), encoding: .utf8)
        let bundled = try String(contentsOf: root.appendingPathComponent("ScarlettGen1Mixer/ScarlettGen1Mixer/Help/user-guide.md"), encoding: .utf8)
        #expect(docs == bundled, "Run scripts/sync-guide.sh to update the app's copy of the user guide")
    }
}

struct ReleaseNotesTests {
    @Test func currentVersionHasReleaseNotes() throws {
        // The version lives only in Version.xcconfig; RELEASE_NOTES.md needs a "## <version>" section for it.
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let config = try String(contentsOf: root.appendingPathComponent("ScarlettGen1Mixer/Version.xcconfig"), encoding: .utf8)
        let line = config.split(separator: "\n").first { $0.trimmingCharacters(in: .whitespaces).hasPrefix("MARKETING_VERSION") }
        let version = try #require(line?.split(separator: "=").last?.trimmingCharacters(in: .whitespaces))
        let notes = try String(contentsOf: root.appendingPathComponent("RELEASE_NOTES.md"), encoding: .utf8)
        #expect(notes.contains("\n## \(version)\n"), "Add a '## \(version)' section to RELEASE_NOTES.md")
    }
}
