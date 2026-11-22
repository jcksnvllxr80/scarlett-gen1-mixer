//
//  AppInfo.swift
//  ScarlettGen1Mixer
//
//  Version and git commit for the About window and the header.
//  The commit is written into the app by scripts/package.sh (BuildInfo.plist);
//  builds made straight from Xcode show "dev".
//

import AppKit

enum AppInfo {
    static var version: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?" }
    static var commit: String {
        guard let url = Bundle.main.url(forResource: "BuildInfo", withExtension: "plist"),
              let info = NSDictionary(contentsOf: url), let c = info["GitCommit"] as? String, !c.isEmpty else { return "dev" }
        return c
    }

    /// Short form for the header: "v0.0.1 · a1b2c3d".
    static var short: String { "v\(version) · \(commit)" }

    @MainActor static func showAbout() {
        let credits = NSAttributedString(
            string: "Commit \(commit)\nA mixer for 1st-gen Focusrite Scarlett interfaces.\nNot affiliated with Focusrite.",
            attributes: [.font: NSFont.systemFont(ofSize: 11), .foregroundColor: NSColor.secondaryLabelColor])
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: "Scarlett Gen 1 Mixer",
            .applicationVersion: version,
            .version: "",   // no "(build n)" after the version
            .credits: credits,
        ])
        NSApp.activate(ignoringOtherApps: true)
    }
}
