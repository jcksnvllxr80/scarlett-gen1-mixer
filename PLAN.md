# Plan

Work through the phases in order. Check off items as they're done, and note findings in `docs/`.

## Phase 1: Protocol spec

- [x] Read `mixer_scarlett.c` and write `docs/protocol.md`: request format, unit IDs, value encodings, and the 18i20 tables (inputs, outputs, mixes, routing sources).
- [ ] Mark each entry *Linux* until it's confirmed on hardware, then *confirmed*.

## Phase 2: ScarlettKit and the command-line tool

- [x] Create the Xcode project (`ScarlettGen1Mixer.xcodeproj`) with three targets: the `ScarlettKit` framework, the `scarlett` command-line tool and the app (placeholder for now). Confirm the Xcode MCP server can build it.
- [x] `ScarlettKit`: find devices (vendor `0x1235` plus the supported product IDs in `ScarlettKit`), open the device, and send control requests from arm64. `IOUSBHost` works (no capture needed), so the old IOKit interface isn't needed.
- [ ] `ScarlettKit`: handle plug and unplug.
- [x] `scarlett info` and `scarlett dump` (read-only state dump).
- [ ] The user checks the dump values against the hardware (output volumes, and "Off" = raw 46).
- [ ] Writes, one control type at a time, each approved by the user: `scarlett set …` for volume, mute, mix gain and route.

## Feature parity with Scarlett MixControl

From the *Scarlett 18i20 1st Gen User Guide* (MixControl chapter, pp. 20–34). **HW** = a device control; **SW** = app logic built on HW controls; **?** = device control not yet mapped (capture it by using that control in MixControl while logging).

**Mixer** (guide says "16 mono / 8 stereo mixes"; the hardware, the Linux driver and the captures all show 8 mono mixes A–H, i.e. 4 stereo)
- [x] Input source per channel (Inputs / DAW): HW `0x32` (read)
- [ ] Fader −∞…+6 dB, double-click = 0 dB: HW `0x3c` (write `0x0100 | node`, per the capture)
- [ ] Pan (stereo mixes): SW → L/R gains
- [ ] Mute, Solo, PFL (pre-fade to Monitor 1/2): SW
- [ ] Stereo link of odd/even channels: SW
- [ ] Channel names: SW (saved in app settings)
- [x] Channel meter, pre-fade: HW meters (read). [ ] Peak hold and clip light with click-to-reset: SW
- [ ] Output channel: mix level, mute, solo, stereo, name, "Sel…" output routing: SW + HW `0x33`
- [ ] Copy Mix To…: SW

**Routing**
- [x] Source per physical output: HW `0x33` (read). [ ] Change it (write)
- [x] Source per channel recorded to the computer: HW `0x34` (read). [ ] Change it (write)
- [ ] Routing presets: Clear, DAW Tracking, Zero Latency Tracking, Mixing: SW
- [ ] Note: Headphones 1 follows Line 7/8, Headphones 2 follows Line 9/10

**Monitor section**
- [ ] Per-line-output state (controlled / muted / fixed full level): MEM `0x3c` `0x000a` = outputs that follow the hardware knob (mapped); `0x000b` and `0x000c` are masks with unknown roles
- [ ] Monitor presets: Off, Mono, Stereo, Quad, 2.1, 5.1, 7.1, Mid + Phones 1, Mini + Phones 2: SW
- [ ] Software monitor level knob: HW `0x0a` output volumes (write)
- [x] Hardware knob level: HW MEM `0x3c/0x0004` (read). [ ] HW Control on/off: mask `0x000a` plus software level (mapped)
- [ ] Dim = MEM `0x0006`, Mute = MEM `0x0005`, L/R Mute = output mutes, Mono = `0x14/0x0a0N` (all mapped; write-only, so the app remembers them)
- [ ] −20 dB Pad: `0x14/0x0801` (mapped, readable)

**Device status**
- [x] Sample rate, sync source and sync status (read). [ ] Change sample rate (through CoreAudio) and sync source (HW `0x28`)

**File menu**
- [x] Open / Save / Save As settings files (`.scarlettmix`), Open Recent
- [x] Restore Factory Defaults (writes the observed power-on defaults)
- [x] Save to Hardware (stand-alone mode): HW MEM `0x3c/0x005a` = `0xA5`, behind a confirmation. **Not yet tested on hardware.**

**Next research step:** with the logger running, the user clicks each **?** control in MixControl once, in a known order, so each one can be mapped from the log.

## Phase 3: The app

**Approved design: Monitor-first** (`docs/ui-mockup.html`). A top band with a large monitor knob and Dim / Mute / L / R / Mono / −20 dB Pad, output LEDs 1–10 and status chips; a middle band with mix chips and 18 slim faders with LED meters and M/S; a bottom band with the routing patch-bay grid (outputs × sources). Near-black background, teal accent, monospaced numbers.


- [ ] SwiftUI window: routing, mixes, monitor section (volume, dim, mute), sample rate and clock status.
- [ ] Read state on connect, apply changes live, and add "Save to device".
- [ ] Snapshots: save and load to a file.

## Done since: menu bar (all window actions), compact monitor section, collapsible sections, scale-to-fit window (fixed size or full screen), user guide

## Phase 4: Meters

- [ ] Work out the meter request (the Linux driver covers it only partly), then add live meters.

## Phase 5: Release

- [ ] Concise README with screenshots and build-from-source steps.
- [ ] Ask testers with the 6i6, 8i6, 18i6 and 18i8 to try it.
- [ ] Build script that produces a `.dmg` (with `hdiutil`): the app plus an Applications shortcut to drag onto.
- [ ] GitHub release with the `.dmg` (ad-hoc signed; document right-click → Open).
