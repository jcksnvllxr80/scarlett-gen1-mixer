# Release notes

Each version gets a section. The release pipeline uses the section matching the version in
`ScarlettGen1Mixer/Version.xcconfig` as the GitHub release description.

## 0.0.1

First preview release, for the 1st-gen Scarlett 18i20 on macOS 26 or later. Other 1st-gen models are untested.

- **Monitor:** live hardware-knob level; DIM, MUTE, MONO, L/R mutes and −20 dB pad; output lights; lock status.
- **Clock:** sample rate (44.1–96 kHz) and clock source (Internal, S/PDIF, ADAT), kept in step with Audio MIDI Setup.
- **Mixer:** colour-coded mix tabs; 8 mono mixes used as stereo or mono pairs; 18 channels in stereo pairs with source pickers, faders, pan or balance, M/S, live meters and mono split.
- **Routing:** a patch-bay matrix with click, shift-click column fill, drag-box route or clear, hover readout, and renameable input and DAW columns.
- **Setups:** save, open and recent `.scarlettmix` files in Documents ▸ Scarlett Gen 1 Mixer; Save to Interface; Restore Factory Defaults.
- **App:** dark and light appearance, full menu bar, collapsible sections, a window that scales to fit (fixed size or full screen), built-in user guide, clean shutdown, and a drag-to-install disk image.
- **Known issue:** after a power cycle, the interface plays the settings saved to it but reports defaults, so the app shows defaults until you open a setup.
