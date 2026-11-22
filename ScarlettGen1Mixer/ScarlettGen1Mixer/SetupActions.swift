//
//  SetupActions.swift
//  ScarlettGen1Mixer
//
//  File panels and confirmations for setups, shared by the menu bar and the Setup buttons.
//

import AppKit
import UniformTypeIdentifiers

@MainActor
enum SetupActions {
    static let fileType = UTType(filenameExtension: "scarlettmix") ?? .json
    static let guideURL = URL(string: "https://github.com/jcksnvllxr80/scarlett-gen1-mixer/blob/main/docs/user-guide.md")!

    /// Where setups live: ~/Documents/Scarlett Gen 1 Mixer (created when needed). Open and
    /// Save As always start here. Not inside the app: updates replace the whole app.
    static var setupsFolder: URL {
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Scarlett Gen 1 Mixer", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static func showSetupsFolder() { NSWorkspace.shared.open(setupsFolder) }

    static func open(_ model: MixerModel) {
        let panel = NSOpenPanel()
        panel.directoryURL = setupsFolder
        panel.allowedContentTypes = [fileType]
        panel.message = "Open a saved setup. It will be sent to the interface."
        guard panel.runModal() == .OK, let url = panel.url else { return }
        open(url, model)
    }

    static func open(_ url: URL, _ model: MixerModel) {
        do { try model.open(url) } catch { show(error, "Couldn't open the setup") }
    }

    static func save(_ model: MixerModel) {
        if let url = model.setupURL { do { try model.save(to: url) } catch { show(error, "Couldn't save the setup") } }
        else { saveAs(model) }
    }

    static func saveAs(_ model: MixerModel) {
        let panel = NSSavePanel()
        panel.directoryURL = setupsFolder
        panel.allowedContentTypes = [fileType]
        panel.nameFieldStringValue = (model.setupURL?.deletingPathExtension().lastPathComponent ?? "My Setup") + ".scarlettmix"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { try model.save(to: url) } catch { show(error, "Couldn't save the setup") }
    }

    static func saveToInterface(_ model: MixerModel) {
        let alert = NSAlert()
        alert.messageText = "Save to the interface's memory?"
        alert.informativeText = "The current settings replace the ones stored in the Scarlett. It will start up with them after a power cycle, even without a computer."
        alert.addButton(withTitle: "Save to Interface")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn { model.saveToHardware() }
    }

    static func restoreFactoryDefaults(_ model: MixerModel) {
        let alert = NSAlert()
        alert.messageText = "Restore factory defaults?"
        alert.informativeText = "Routing, mixer levels and monitor settings go back to the interface's power-on defaults. Every input is mixed at 0 dB, so turn your speakers down first."
        alert.addButton(withTitle: "Restore Defaults")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        guard let f = model.factorySetup() else { show(MixerModel.SetupError.noDevice, "Couldn't restore defaults"); return }
        do { try model.apply(f); model.newSetupState() } catch { show(error, "Couldn't restore defaults") }
    }

    static func show(_ error: Error, _ title: String) {
        let alert = NSAlert(error: error)
        alert.messageText = title
        alert.informativeText = error.localizedDescription
        alert.runModal()
    }
}
