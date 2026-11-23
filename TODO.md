# TODO

## Help

- [x] **Show the user guide inside the app.** Help ▸ User Guide opens a window that renders `docs/user-guide.md` as formatted Markdown (headings, tables, lists, code blocks) in the app's dark theme, instead of opening GitHub.
  - Bundle `docs/user-guide.md` into the app (copy it into the app's resources at build time).
  - Render it: convert Markdown to HTML with a small built-in converter and show it in a `WKWebView` with app-theme CSS. SwiftUI `Text` can't render tables or block elements.
  - Links inside the guide (e.g. `#setups-save-and-recall`) should scroll within the window.
- [x] **Separate Help ▸ View Source on GitHub** item that opens the repository page. *Done in 0.1.0.*

## First GitHub release

- [ ] **Publish the repo and make the first release.**
  - Create the public GitHub repo (`jcksnvllxr80/scarlett-gen1-mixer`) and push.
  - **Squash the local working commits** into a clean history first (the user's preference).
  - Tag `v1.0.0` so the release workflow builds the `.dmg` and attaches it to the release.
  - Afterwards: add Help ▸ View Source on GitHub, and point Help/update links at the live repo.

## Updates and installation

- [x] **Check for updates and install in place (Sparkle).** *Done in 0.1.0:* Sparkle 2 package; `SUFeedURL` and `SUPublicEDKey` in `ScarlettGen1Mixer/Info.plist`; private key in the Keychain (account `scarlett-gen1-mixer`) and the `SPARKLE_PRIVATE_KEY` GitHub secret; `scripts/make-appcast.sh` signs the zip and writes `appcast.xml`, attached to each release. **Still to test with the user:** install 0.1.0, release 0.1.1, check it updates in place, relaunches and reconnects.
  1. **Add Sparkle 2** (free, open source, the standard Mac updater) as a Swift package to the app target, embedded and signed. Adding the package is a one-time step in Xcode (File ▸ Add Package Dependencies…), since the Xcode tools can't add packages.
  2. **Signing key:** run Sparkle's `generate_keys` once. The public key goes in the app's Info.plist (`SUPublicEDKey`). The private key is stored only as a GitHub secret (`SPARKLE_PRIVATE_KEY`), never in the repo. The app refuses any update not signed with it.
  3. **Update feed:** `appcast.xml` (version, release notes, download link and signature) is attached to every release. The app reads `https://github.com/jcksnvllxr80/scarlett-gen1-mixer/releases/latest/download/appcast.xml` (`SUFeedURL`), so no separate website is needed.
  4. **Pipeline:** when it creates a release, it also zips the app, signs the zip with `sign_update` using the secret, builds `appcast.xml` (release notes from `RELEASE_NOTES.md`), and attaches both alongside the `.dmg`.
  5. **App:** "Check for Updates…" in the app menu, plus an automatic check once a day (Sparkle asks the user the first time). The update window shows the release notes, then **Install and Relaunch** replaces the app in Applications.
  6. **Test with the user:** install release N, publish N+1, check that the app finds it, installs it and relaunches, and that the interface reconnects. Also check that a tampered download is refused. Ad-hoc signing is new for Sparkle here, so this test decides whether it works without a paid account.
  - Docs: README (one line: the app updates itself), user guide (Check for Updates), release notes.
- [x] **Releases.** `.github/workflows/build.yml` builds, tests and packages on every push to main/master. It creates a GitHub Release (tag `v<version>`, `.dmg` attached) **only when the app's version has no release yet**. To release, bump `Version.xcconfig`, add release notes, and push.
- [x] **Versioning.** The version lives on **one line** in `ScarlettGen1Mixer/Version.xcconfig` (starting at 0.0.1), the app target's base configuration. `scripts/version.sh` reads it for packaging and CI. The build number comes from the CI run (or the commit count locally). The standard About window shows it.
- [x] **Release notes.** `RELEASE_NOTES.md` has one section per version, used as the GitHub release description. A unit test requires a section for the current version.
- [x] **Installation.** `scripts/package.sh` builds a styled `.dmg`: opening it shows the app, an arrow and the Applications folder on the matrix background (`packaging/dmg/`), so users drag the app across to install. The first-launch tip (System Settings ▸ Privacy & Security ▸ Open Anyway) is on the background. The README has an **Install** section.
- [ ] **Homebrew cask** (optional, *after the first GitHub release*): `brew install --cask …` pointing at the GitHub release `.dmg`.

## Hardware follow-ups

- [ ] **Bug (open): after a power cycle the app shows defaults, not the settings the interface restored.** Save to Interface works, but the 18i20 reads back defaults after power-up (see `docs/protocol.md`). MixControl doesn't show them either. Possible fix, not decided: keep a copy of what was saved and re-send it after a power cycle.
- [x] First **Open Setup** test (about 200 writes in one go); check the write log afterwards. *Passed 2026-11-22: 208 writes in about 1 s, no hang, the setup restored correctly (checked by the user).*
- [ ] Confirm the meter dB scale on a loud signal.
- [ ] **Clock lock test with the ADAT expander:** set CLOCK to ADAT, expander as clock master at the same rate → app shows LOCKED; change the expander's rate or switch it off → app should show NO LOCK within about 1 s. Set CLOCK back to INTERNAL afterwards.

## Look and Feel

- [x] Icon needs work. should be just the "cool S" almost filling the icon space withsolid background. on splash screen that should be just the S on a background with looking for device. not icon block on splash. *Done: glowing neon-line S on a solid dark tile (`docs/icon/make-icon.swift icon`); the splash shows the S alone (`make-icon.swift mark`, asset `SplashMark`).*

## build | release

- [x] add versioning to app, and show in help menu about and on top pane somewhere out of the way in a dim font. might need git hash for fun too. *Done: dim `v0.0.1 · <commit>` at the top right of MONITOR; About (app menu and Help) shows version, build and commit, stamped by `scripts/package.sh`.*
- [x] add release to github pipeline and tagging *Done: `.github/workflows/build.yml` tags `v<version>` and creates the release (with notes from `RELEASE_NOTES.md`) when the version is new.*