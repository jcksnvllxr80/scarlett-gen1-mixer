# scarlett-gen1-mixer

A native macOS mixer and router for **1st-gen Focusrite Scarlett** interfaces (6i6, 8i6, 18i6, 18i8, 18i20). Built for Apple Silicon and open source.

**Status:** early development. **[User guide](docs/user-guide.md)**: how the mixer works and what every control does.

## Install

Requires **macOS 26 or later**.

1. Download `ScarlettGen1Mixer-<version>.dmg` from the [latest release](https://github.com/jcksnvllxr80/scarlett-gen1-mixer/releases/latest).
2. Open it and drag the app onto **Applications**.
3. Open the app from Applications. If macOS says it can't verify the developer, go to **System Settings ▸ Privacy & Security** and click **Open Anyway**. You only need to do this once.

## Why

These interfaces still work as audio devices on current macOS, but their built-in mixer and routing can't be changed. Focusrite's Scarlett MixControl was last updated at version 1.10.6 (tested up to macOS 10.15). It's Intel-only and doesn't detect the interface on recent macOS. Focusrite has also ended development support for the 1st-gen 8i6 and 18i6.

## Protocol source

The Linux kernel driver [`sound/usb/mixer_scarlett.c`](https://github.com/torvalds/linux/blob/master/sound/usb/mixer_scarlett.c).

## Versions and releases

- The version is set in one place: **`ScarlettGen1Mixer/Version.xcconfig`** (`MARKETING_VERSION`).
- Every push to `main` builds and tests the app. When the version has no GitHub release yet, the pipeline publishes one with the `.dmg` attached.
- To release: bump the version, add a section for it to **[`RELEASE_NOTES.md`](RELEASE_NOTES.md)**, then push.

## License

[MIT](LICENSE). Provided as-is, without warranty. Not affiliated with Focusrite. Focusrite and Scarlett are trademarks of Focusrite Audio Engineering Ltd.
