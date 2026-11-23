//
//  ScarlettGen1MixerApp.swift
//  ScarlettGen1Mixer
//

import SwiftUI
import ScarlettKit
import Sparkle

/// Quits cleanly: lets the USB loop finish its current request, sends any queued changes,
/// and closes the device before the app exits. Also turns SIGTERM (e.g. `kill`) into a normal Quit.
final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = MixerModel()
    /// Sparkle: checks the GitHub release feed (Info.plist SUFeedURL), verifies the signature,
    /// installs in place and relaunches. Asks the user before turning on automatic checks.
    let updater = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
    private var sigterm: DispatchSourceSignal?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Appearance.apply()
        signal(SIGTERM, SIG_IGN)
        let src = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
        // Ask to quit from the run loop, not from inside this main-queue block: terminating
        // blocks until shutdown finishes, and shutdown needs the main queue to be free.
        src.setEventHandler {
            RunLoop.main.perform(inModes: [.default]) { NSApp.terminate(nil) }
        }
        src.resume()
        sigterm = src
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        var replied = false
        func reply() { if !replied { replied = true; NSApp.reply(toApplicationShouldTerminate: true) } }
        Task { @MainActor in
            await model.shutdown()
            reply()
        }
        // Never hang on quit: give up waiting after a couple of seconds.
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { reply() }
        return .terminateLater
    }
}

@main
struct ScarlettGen1MixerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    private var model: MixerModel { appDelegate.model }
    @State private var layout = LayoutState()

    var body: some Scene {
        WindowGroup {
            ContentView(model: model, layout: layout)
        }
        .commands { AppCommands(model: model, layout: layout, updater: appDelegate.updater.updater) }
        Window("User Guide", id: "guide") { GuideView() }
            .defaultSize(width: 900, height: 900)
    }
}

/// The menu bar: everything the window can do, organised by section.
struct AppCommands: Commands {
    let model: MixerModel
    let layout: LayoutState
    let updater: SPUUpdater
    @Environment(\.openWindow) private var openWindow
    @AppStorage(Appearance.key) private var appearance = Appearance.dark.rawValue

    private func toggle(_ get: @escaping () -> Bool, _ action: @escaping () -> Void) -> Binding<Bool> {
        Binding(get: get, set: { _ in action() })
    }

    var body: some Commands {
        // App menu: About with version, build and commit
        CommandGroup(replacing: .appInfo) {
            Button("About Scarlett Gen 1 Mixer") { AppInfo.showAbout() }
            Button("Check for Updates…") { updater.checkForUpdates() }
        }

        // File
        CommandGroup(replacing: .newItem) {
            Button("Open Setup…") { SetupActions.open(model) }.keyboardShortcut("o")
            Menu("Open Recent") {
                ForEach(model.recentSetups, id: \.self) { url in
                    Button(url.deletingPathExtension().lastPathComponent) { SetupActions.open(url, model) }
                }
                if !model.recentSetups.isEmpty { Divider() }
                Button("Clear Menu") { model.recentSetups = [] }.disabled(model.recentSetups.isEmpty)
            }
        }
        CommandGroup(replacing: .saveItem) {
            Button("Save Setup") { SetupActions.save(model) }.keyboardShortcut("s")
            Button("Save Setup As…") { SetupActions.saveAs(model) }.keyboardShortcut("s", modifiers: [.command, .shift])
            Button("Show Setups Folder") { SetupActions.showSetupsFolder() }
            Divider()
            Button("Save to Interface…") { SetupActions.saveToInterface(model) }
            Button("Restore Factory Defaults…") { SetupActions.restoreFactoryDefaults(model) }
        }

        // Monitor
        CommandMenu("Monitor") {
            Toggle("Dim", isOn: toggle({ model.dim }, model.toggleDim)).keyboardShortcut("d")
            Toggle("Mute", isOn: toggle({ model.monitorMute }, model.toggleMonitorMute)).keyboardShortcut("m", modifiers: [.command, .shift])
            Toggle("Mute Left", isOn: toggle({ model.sideMuted(left: true) }, { model.toggleSide(left: true) }))
            Toggle("Mute Right", isOn: toggle({ model.sideMuted(left: false) }, { model.toggleSide(left: false) }))
            Divider()
            Toggle("Mono", isOn: toggle({ model.mono }, model.toggleMono))
            Toggle("−20 dB Pad", isOn: toggle({ model.state?.padOn == true }, model.togglePad))
        }

        // Mixer
        CommandMenu("Mixer") {
            ForEach(0..<4, id: \.self) { p in
                Button("Mix \(2 * p + 1)/\(2 * p + 2)") {
                    layout.target = model.monoPairs.contains(p) ? [2 * p] : [2 * p, 2 * p + 1]
                }
                .keyboardShortcut(KeyEquivalent(Character("\(p + 1)")))
            }
            Divider()
            Toggle("Current Mix Is Stereo", isOn: toggle({ !model.monoPairs.contains((layout.target.first ?? 0) / 2) }, {
                let p = (layout.target.first ?? 0) / 2
                if model.monoPairs.contains(p) { model.monoPairs.remove(p); layout.target = [2 * p, 2 * p + 1] }
                else { model.monoPairs.insert(p); layout.target = [2 * p] }
            }))
        }

        // Routing
        CommandMenu("Routing") {
            Button("Reset Input and DAW Names") { model.sourceNames = [:] }
        }

        // View
        CommandGroup(before: .toolbar) {
            Toggle("Show Monitor", isOn: toggle({ !layout.isCollapsed(.monitor) }, { layout.toggleCollapsed(.monitor) }))
                .keyboardShortcut("1", modifiers: [.command, .option])
            Toggle("Show Mixer", isOn: toggle({ !layout.isCollapsed(.mixer) }, { layout.toggleCollapsed(.mixer) }))
                .keyboardShortcut("2", modifiers: [.command, .option])
            Toggle("Show Routing", isOn: toggle({ !layout.isCollapsed(.patchbay) }, { layout.toggleCollapsed(.patchbay) }))
                .keyboardShortcut("3", modifiers: [.command, .option])
            Picker("Appearance", selection: Binding(get: { Appearance(rawValue: appearance) ?? .dark },
                                                    set: { Appearance.set($0) })) {
                ForEach(Appearance.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            Button("Reset Layout") {
                layout.collapsed = []
            }
            Divider()
        }

        // Device
        CommandMenu("Device") {
            Picker("Sample Rate", selection: Binding(get: { model.clock.rate ?? 0 }, set: { model.setSampleRate($0) })) {
                ForEach(model.clock.rates, id: \.self) { Text("\(kHzText($0)) kHz").tag($0) }
            }
            Picker("Clock Source", selection: Binding(get: { model.clock.source ?? 0 }, set: { model.setClockSource($0) })) {
                ForEach(model.clock.sources, id: \.id) { Text($0.name).tag($0.id) }
            }
            Divider()
            Button("Refresh from Device") { model.refresh() }.keyboardShortcut("r")
        }

        // Help
        CommandGroup(replacing: .help) {
            Button("Scarlett Gen 1 Mixer User Guide") { openWindow(id: "guide") }.keyboardShortcut("?")
            Button("View Source on GitHub") { NSWorkspace.shared.open(SetupActions.sourceURL) }
            Divider()
            Button("About Scarlett Gen 1 Mixer") { AppInfo.showAbout() }
        }
    }
}
