//
//  ContentView.swift
//  ScarlettGen1Mixer
//
//  "Monitor-first" layout (docs/ui-mockup.html): monitor band on top, faders
//  for the selected stereo mix in the middle, routing patch bay at the bottom.
//  Only mixer levels are writable so far; everything else shows device state.
//

import SwiftUI
import AppKit
import ScarlettKit

// MARK: Theme

/// Dark or light, chosen in View ▸ Appearance or the APPEARANCE block. Applies app-wide.
enum Appearance: String, CaseIterable {
    case dark, system, light   // order shown: DARK | AUTO | LIGHT
    static let key = "appearance"
    static var current: Appearance { Appearance(rawValue: UserDefaults.standard.string(forKey: key) ?? "") ?? .dark }
    var title: String { switch self { case .dark: "Dark"; case .light: "Light"; case .system: "Match System" } }
    var short: String { switch self { case .dark: "DARK"; case .light: "LIGHT"; case .system: "AUTO" } }

    static func set(_ a: Appearance) {
        UserDefaults.standard.set(a.rawValue, forKey: key)
        apply()
    }
    @MainActor static func apply() {
        switch current {
        case .dark: NSApp.appearance = NSAppearance(named: .darkAqua)
        case .light: NSApp.appearance = NSAppearance(named: .aqua)
        case .system: NSApp.appearance = nil
        }
    }
}

/// Every colour has a dark and a light value; macOS picks one for the current appearance.
enum Theme {
    private static func color(_ dark: (Double, Double, Double), _ light: (Double, Double, Double)) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let c = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
            return NSColor(srgbRed: c.0, green: c.1, blue: c.2, alpha: 1)
        })
    }
    //                         dark                     light
    static let bg      = color((0.043, 0.051, 0.055), (0.925, 0.933, 0.937))
    static let panel   = color((0.071, 0.082, 0.090), (0.965, 0.969, 0.973))
    static let panel2  = color((0.090, 0.106, 0.114), (0.985, 0.988, 0.990))
    static let line    = color((0.137, 0.161, 0.173), (0.800, 0.824, 0.835))
    static let text    = color((0.84, 0.88, 0.89),    (0.10, 0.13, 0.14))
    static let dim     = color((0.42, 0.48, 0.50),    (0.42, 0.47, 0.49))
    static let accent  = color((0.176, 0.831, 0.749), (0.0, 0.58, 0.51))
    static let amber   = color((0.984, 0.749, 0.141), (0.80, 0.52, 0.0))
    static let blue    = color((0.55, 0.65, 1.0),     (0.25, 0.38, 0.85))
    static let pink    = color((0.93, 0.45, 0.75),    (0.78, 0.22, 0.52))
    static let clip    = color((0.96, 0.25, 0.37),    (0.85, 0.12, 0.26))
    static let mixPanel = color((0.060, 0.070, 0.076), (0.990, 0.992, 0.994))   // inside the selected mix's outline
    // Lit patch-bay cells: a brighter version of each group's hue
    static let mixBright    = color((0.55, 1.0, 0.93),  (0.20, 0.75, 0.67))
    static let analogBright = color((1.0, 0.88, 0.45),  (0.95, 0.68, 0.15))
    static let dawBright    = color((0.78, 0.84, 1.0),  (0.45, 0.58, 0.95))
    /// One colour per mix pair (Mix 1/2, 3/4, 5/6, 7/8): tab outline, and the fader outline when selected.
    static let mixPairColors: [Color] = [accent, amber, blue, pink]
    static func mixPairColor(_ pair: Int) -> Color { mixPairColors[pair % mixPairColors.count] }
    static let mono = Font.system(.caption, design: .monospaced)
}

/// Sizes in one place (like CSS variables). Change a value here to restyle the whole app.
enum Metrics {
    // Monitor section
    static let knobSize: CGFloat = 118
    static let knobStroke: CGFloat = 10
    static let knobFontSize: CGFloat = 28
    static let monitorButtonHeight: CGFloat = 26
    static let monitorButtonWidth: CGFloat = 64
    static let themeButtonHeight: CGFloat = 24
    static let themeButtonFontSize: CGFloat = 10
    static let monitorButtonFontSize: CGFloat = 11
    static let monitorBandPadding: CGFloat = 10
    static let monitorSectionHeight: CGFloat = knobSize   // divider height between top-pane sections
    // Start screen
    static let splashIconSize: CGFloat = 360
    static let splashMinDuration: Double = 1.0     // seconds shown at least
    static let splashFadeDuration: Double = 0.5    // seconds to fade into the app
    // Window: the layout is drawn at the design size, each pane exactly as tall as its
    // contents, then scaled to fit. Two window sizes only: windowed (fixed) or full screen.
    static let designWidth: CGFloat = 1500
    static let designHeight: CGFloat = 1000       // approximate full height; sets the windowed shape
    static let windowedScale: CGFloat = 0.85      // windowed size = design × this (smaller if the screen is)
    // Sections
    static let sectionHeaderHeight: Double = 26
    static let sectionGap: CGFloat = 2            // line between panes
    // Mix tabs and the outlined panel of faders they belong to
    static let mixTabCorner: CGFloat = 8
    static let mixPanelCorner: CGFloat = 10
    static let mixPanelBorder: CGFloat = 1.5
    static let mixTabIdleOpacity = 0.35   // unselected tab outline (lights up fully when selected)
    static let mixTabPadding: CGFloat = 26          // space either side of a tab's label
    static let mixTabGlowWidth: CGFloat = 5         // selected tab's glow (follows the outline)
    static let mixTabGlowRadius: CGFloat = 6
    static let mixTabGlowOpacity = 0.45
    static let mixTabFlare: CGFloat = mixTabCorner  // selected tab's base curves into the border, same radius as its top
    static let mixTabHeight: CGFloat = 30
    static let stereoToggleFontSize: CGFloat = 12   // "⚭ stereo" / "⚭ mono" toggles
    static let pairToggleHeight: CGFloat = 20       // row inside each channel-pair box
    // Fader strips
    static let stripHeight: CGFloat = 320
    static let matrixCellHeight: CGFloat = 13
    static let matrixSpacing: CGFloat = 2
    static let faderTrackWidth: CGFloat = 24
    static let faderCapSize = CGSize(width: 22, height: 10)
    static let meterWidth: CGFloat = 21
    static let meterSegments = 20
    static let meterFloorDB = -60.0      // bottom of the meter
    static let meterWarnDB = -12.0       // amber from here
    static let meterClipDB = -3.0        // red from here
    static let meterUnlitOpacity = 0.14  // unlit segments show their zone colour faintly
    static let panRingSize: CGFloat = 30
    static let panRingStroke: CGFloat = 4
    static let smallButtonSize = CGSize(width: 22, height: 18)
}

func dbText(_ v: Double?) -> String {
    guard let v else { return "—" }
    return v <= -128 ? "−∞" : String(format: "%+.1f", v)
}

// MARK: Root

/// Layout of the sections: which are collapsed (remembered between launches).
@MainActor
@Observable
final class LayoutState {
    enum Section: String { case monitor, mixer, patchbay }

    var target: [Int] = [0, 1]   // selected mix(es): [L, R] for a stereo mix, [m] for mono

    var collapsed: Set<String> = Set(UserDefaults.standard.stringArray(forKey: "collapsedSections") ?? []) {
        didSet { UserDefaults.standard.set(Array(collapsed), forKey: "collapsedSections") }
    }

    func isCollapsed(_ s: Section) -> Bool { collapsed.contains(s.rawValue) }
    func toggleCollapsed(_ s: Section) {
        if collapsed.contains(s.rawValue) { collapsed.remove(s.rawValue) } else { collapsed.insert(s.rawValue) }
    }
}

struct ContentView: View {
    let model: MixerModel
    let layout: LayoutState

    @State private var minTimeElapsed = false
    @State private var contentHeight: CGFloat = Metrics.designHeight   // measured height of the sections
    private var showSplash: Bool { model.state == nil || !minTimeElapsed }

    /// One scale for everything: fit the design width and the measured height in the window.
    private func scale(for size: CGSize) -> CGFloat {
        let h = contentHeight > 100 ? contentHeight : Metrics.designHeight
        return max(0.3, min(size.width / Metrics.designWidth, size.height / h))
    }

    var body: some View {
        ZStack {
            GeometryReader { geo in
                let s = scale(for: geo.size)
                sections
                    .frame(width: geo.size.width / s)              // extra width goes to the content
                    .fixedSize(horizontal: false, vertical: true)  // each pane at its natural height
                    .background(GeometryReader { g in
                        Color.clear.preference(key: ContentHeightKey.self, value: g.size.height)
                    })
                    .scaleEffect(s, anchor: .topLeading)
                    .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
            }
            .onPreferenceChange(ContentHeightKey.self) { h in
                if abs(h - contentHeight) > 0.5 { contentHeight = h }
            }
            if showSplash {
                StartupView(status: model.status)
                    .background(Theme.bg)
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: Metrics.splashFadeDuration), value: showSplash)
        .task {
            try? await Task.sleep(for: .seconds(Metrics.splashMinDuration))
            minTimeElapsed = true
        }
        .foregroundStyle(Theme.text)
        .background(Theme.bg)
        .background(WindowSizer())
        .task { model.start() }
    }

    @ViewBuilder private var sections: some View {
        VStack(spacing: Metrics.sectionGap) {
            if let state = model.state {
                SectionPanel(title: "MONITOR", section: .monitor, layout: layout, trailing: AppInfo.short) {
                    MonitorBand(state: state, meters: model.meters, model: model)
                }
                SectionPanel(title: "MIXER", section: .mixer, layout: layout) {
                    FaderBand(state: state, meters: model.meters,
                              target: Binding(get: { layout.target }, set: { layout.target = $0 }), model: model)
                }
                SectionPanel(title: "ROUTING", section: .patchbay, layout: layout) {
                    PatchBay(state: state, model: model)
                }
            }
        }
        .background(Theme.line.opacity(0.5))
    }
}

struct ContentHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

/// Fixes the window to one size (the design shape, scaled down a little), with full screen as
/// the only other size. Size limits are lifted while in full screen and restored after.
struct WindowSizer: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { NSView() }
    func updateNSView(_ view: NSView, context: Context) {
        DispatchQueue.main.async { context.coordinator.attach(view.window) }
    }
    func makeCoordinator() -> Coordinator { Coordinator() }

    @MainActor final class Coordinator {
        private weak var window: NSWindow?

        func attach(_ w: NSWindow?) {
            guard let w, w !== window else { return }
            window = w
            w.collectionBehavior.insert(.fullScreenPrimary)
            let nc = NotificationCenter.default
            nc.addObserver(forName: NSWindow.willEnterFullScreenNotification, object: w, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.unlock() }
            }
            nc.addObserver(forName: NSWindow.didExitFullScreenNotification, object: w, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.lock(center: false) }
            }
            if !w.styleMask.contains(.fullScreen) { lock(center: true) }
        }

        private var windowedSize: NSSize {
            let visible = (window?.screen ?? NSScreen.main)?.visibleFrame.size ?? NSSize(width: 1440, height: 900)
            let titleBar: CGFloat = 32
            let s = min(Metrics.windowedScale,
                        visible.width * 0.96 / Metrics.designWidth,
                        (visible.height - titleBar) * 0.96 / Metrics.designHeight)
            return NSSize(width: (Metrics.designWidth * s).rounded(), height: (Metrics.designHeight * s).rounded())
        }

        private func lock(center: Bool) {
            guard let w = window else { return }
            let size = windowedSize
            w.contentMinSize = size
            w.contentMaxSize = size
            w.setContentSize(size)
            if center { w.center() }
        }

        private func unlock() {
            guard let w = window else { return }
            w.contentMinSize = NSSize(width: 400, height: 300)
            w.contentMaxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        }
    }
}

/// Shown until a device is connected: the app icon pulsing, and what we're doing.
struct StartupView: View {
    let status: String
    @State private var pulse = false
    @State private var since = Date()

    var body: some View {
        VStack(spacing: 22) {
            Image("SplashMark")   // just the S, no icon tile
                .resizable().interpolation(.high)
                .frame(width: Metrics.splashIconSize, height: Metrics.splashIconSize)
                .shadow(color: Theme.accent.opacity(pulse ? 0.55 : 0.15), radius: pulse ? 40 : 12)
                .scaleEffect(pulse ? 1.02 : 0.98)
                .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true), value: pulse)
            HStack(spacing: 10) {
                ProgressView().controlSize(.small)
                Text("Looking for your Scarlett…")
                    .font(.system(.title3, design: .monospaced).weight(.semibold))
                    .foregroundStyle(Theme.accent)
            }
            TimelineView(.periodic(from: .now, by: 1)) { ctx in
                if ctx.date.timeIntervalSince(since) > 4 {
                    VStack(spacing: 6) {
                        Text("Check that it's connected by USB and switched on, and that no other mixer app is open.")
                        Text(status).font(.caption).foregroundStyle(Theme.dim.opacity(0.8))
                    }
                    .font(.callout).foregroundStyle(Theme.dim)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 520)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { pulse = true; since = .now }
    }
}

/// A section with a header bar: title and minimize.
struct SectionPanel<Content: View>: View {
    let title: String
    let section: LayoutState.Section
    let layout: LayoutState
    var trailing: String? = nil
    @ViewBuilder let content: () -> Content
    @State private var headerHover = false

    var body: some View {
        let collapsed = layout.isCollapsed(section)
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: collapsed ? "chevron.right" : "chevron.down")
                    .frame(width: 14)
                Text(title).font(.caption.weight(.bold)).tracking(2)
                Spacer()
                if let trailing {
                    Text(trailing).font(.system(size: 10, design: .monospaced)).foregroundStyle(Theme.dim.opacity(0.6))
                        .help("Version \(AppInfo.version), commit \(AppInfo.commit)")
                }
            }
            .foregroundStyle(headerHover ? Theme.text : Theme.dim)
            .padding(.horizontal, 16).frame(height: Metrics.sectionHeaderHeight)
            .background(headerHover ? Theme.panel2 : Theme.panel)
            .contentShape(Rectangle())                       // the whole bar is the click target
            .onTapGesture { layout.toggleCollapsed(section) }
            .onHover { headerHover = $0 }
            .help(collapsed ? "Click to expand" : "Click to minimize")
            if !collapsed {
                content()
                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .top)
            }
        }
        .background(Theme.bg)
    }
}

// MARK: Monitor band

struct MonitorBand: View {
    let state: MixerState
    let meters: Meters?
    let model: MixerModel


    var body: some View {
        HStack(alignment: .top, spacing: 22) {   // every section starts on the same top line
            MonitorKnob(dB: meters?.monitorKnobDB)
            // Monitor buttons (2 rows × 3), with the output lights centred underneath
            VStack(spacing: 10) {
                Grid(horizontalSpacing: 6, verticalSpacing: 6) {
                    GridRow {
                        MonButton(title: "DIM", on: model.dim, color: Theme.amber) { model.toggleDim() }
                        MonButton(title: "MUTE", on: model.monitorMute, color: .red) { model.toggleMonitorMute() }
                        MonButton(title: "MONO", on: model.mono, color: Theme.accent) { model.toggleMono() }
                    }
                    GridRow {
                        MonButton(title: "L", on: model.sideMuted(left: true), color: .red) { model.toggleSide(left: true) }
                        MonButton(title: "R", on: model.sideMuted(left: false), color: .red) { model.toggleSide(left: false) }
                        MonButton(title: "−20 PAD", on: state.padOn == true, color: Theme.amber) { model.togglePad() }
                    }
                }
                .frame(width: Metrics.monitorButtonWidth * 3 + 12)
                VStack(alignment: .center, spacing: 6) {
                Text("OUTPUTS").font(.caption2.weight(.bold)).tracking(2).foregroundStyle(Theme.dim)
                HStack(spacing: 8) {
                    ForEach(0..<10, id: \.self) { i in
                        let ch = channel(bus: i + 1)
                        let on = ch?.source != nil && ch?.source != .off && ch?.muted == false
                        VStack(spacing: 3) {
                            Circle().fill(on ? Theme.accent : Theme.line).frame(width: 9, height: 9)
                                .shadow(color: on ? Theme.accent : .clear, radius: 4)
                            Text("\(i + 1)").font(.system(size: 9, design: .monospaced)).foregroundStyle(Theme.dim)
                        }
                        .help("Line \(i + 1): \(ch?.source.map { "\($0)" } ?? "?")\(ch?.muted == true ? ", muted" : "")")
                    }
                }
            }
            }
            // New sections go between the monitor controls and SETUP
            SectionDivider()
            ClockBlock(model: model, fallbackRate: state.sampleRate, fallbackSource: state.clockSource.map { "\($0)".capitalized })
                SectionDivider()
            AppearanceBlock()
            SectionDivider()
            SetupBlock(model: model)
            Spacer(minLength: 12)
            VStack(alignment: .trailing, spacing: 5) {
                Text(state.model.name).foregroundStyle(Theme.accent)
                Text(state.syncLocked == true ? "● LOCKED" : "○ NO LOCK")
                    .foregroundStyle(state.syncLocked == true ? Theme.accent : Theme.amber)
            }
            .font(.system(.callout, design: .monospaced).weight(.semibold))
        }
        .padding(.horizontal, 24).padding(.vertical, Metrics.monitorBandPadding)
        .background(LinearGradient(colors: [Theme.panel2, Theme.panel], startPoint: .top, endPoint: .bottom))
    }

    private func channel(bus: Int) -> ChannelState? {
        let k = (bus - 1) / 2
        guard state.outputs.indices.contains(k) else { return nil }
        return bus % 2 == 1 ? state.outputs[k].left : state.outputs[k].right
    }
}

/// Vertical line between top-pane sections, the full section height.
struct SectionDivider: View {
    var body: some View { Rectangle().fill(Theme.line).frame(width: 1, height: Metrics.monitorSectionHeight) }
}

/// Current setup name (with an unsaved-changes dot) and the save/open buttons.
struct SetupBlock: View {
    let model: MixerModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("SETUP").font(.caption2.weight(.bold)).tracking(2).foregroundStyle(Theme.dim)
                Text(model.setupURL?.deletingPathExtension().lastPathComponent ?? "Untitled")
                    .font(.system(.callout, design: .monospaced).weight(.semibold))
                    .lineLimit(1)
                if model.isModified {
                    Circle().fill(Theme.amber).frame(width: 7, height: 7).help("Unsaved changes")
                }
            }
            HStack(spacing: 6) {
                Button("OPEN…") { SetupActions.open(model) }
                Button("SAVE") { SetupActions.save(model) }
                Button("SAVE AS…") { SetupActions.saveAs(model) }
            }
            .buttonStyle(ThemeButtonStyle())
            Button("SAVE TO INTERFACE…") { SetupActions.saveToInterface(model) }
                .buttonStyle(ThemeButtonStyle(tint: Theme.amber))
                .help("Store the current settings in the Scarlett's memory (kept after power off)")
        }
    }
}

/// Dark / light / follow macOS (also in View ▸ Appearance): a horizontal sliding selector.
struct AppearanceBlock: View {
    @AppStorage(Appearance.key) private var stored = Appearance.dark.rawValue

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("APPEARANCE").font(.caption2.weight(.bold)).tracking(2).foregroundStyle(Theme.dim)
            SlidingSelector(options: Appearance.allCases.map { ($0, $0.short) },
                            selection: Binding(get: { Appearance(rawValue: stored) ?? .dark }, set: { Appearance.set($0) }))
                .help("Dark, light, or AUTO to follow macOS")
        }
    }
}

/// One pill with a segment per option; a highlight slides to the chosen one.
struct SlidingSelector<T: Hashable>: View {
    let options: [(T, String)]
    @Binding var selection: T
    @Namespace private var ns

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.0) { value, label in
                let on = value == selection
                Text(label)
                    .font(.system(size: Metrics.themeButtonFontSize, weight: .heavy)).tracking(1)
                    .foregroundStyle(on ? Theme.bg : Theme.dim)
                    .padding(.horizontal, 10).frame(height: Metrics.themeButtonHeight - 4)
                    .background {
                        if on { Capsule().fill(Theme.accent).matchedGeometryEffect(id: "knob", in: ns) }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { withAnimation(.easeOut(duration: 0.18)) { selection = value } }
            }
        }
        .padding(2)
        .background(Theme.panel2, in: Capsule())
        .overlay(Capsule().stroke(Theme.line))
    }
}

/// Sample rate and clock source (the same settings as Audio MIDI Setup; macOS applies them).
struct ClockBlock: View {
    let model: MixerModel
    let fallbackRate: UInt32?
    let fallbackSource: String?

    var body: some View {
        let rate = model.clock.rate ?? fallbackRate.map(Double.init)
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("CLOCK").font(.caption2.weight(.bold)).tracking(2).foregroundStyle(Theme.dim)
                Text("\(rate.map(kHzText) ?? "?") kHz · \(model.clock.sourceName ?? fallbackSource ?? "?")")
                    .font(.system(.callout, design: .monospaced).weight(.semibold))
                    .lineLimit(1)
            }
            HStack(spacing: 6) {
                ForEach(model.clock.rates, id: \.self) { hz in
                    Button(kHzText(hz)) { model.setSampleRate(hz) }
                        .buttonStyle(ThemeButtonStyle(selected: hz == rate))
                }
            }
            .help("Sample rate in kHz. Changing it briefly interrupts audio.")
            HStack(spacing: 6) {
                ForEach(model.clock.sources, id: \.id) { src in
                    Button(src.name.uppercased()) { model.setClockSource(src.id) }
                        .buttonStyle(ThemeButtonStyle(selected: src.id == model.clock.source))
                }
            }
            .help("Clock source: INTERNAL = this interface sets the clock. S/PDIF or ADAT = follow that input, e.g. an ADAT expander set as clock master.")
        }
    }
}

/// Small button in the app's style: dark fill, thin outline, bold caps; tinted outline on hover, filled while pressed.
struct ThemeButtonStyle: ButtonStyle {
    var tint: Color = Theme.accent
    var selected = false      // the current choice in a row of options: lit in the tint colour
    @State private var hovering = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: Metrics.themeButtonFontSize, weight: .heavy)).tracking(1)
            .foregroundStyle(configuration.isPressed ? Theme.bg : (hovering || selected ? tint : Theme.dim))
            .padding(.horizontal, 10).frame(height: Metrics.themeButtonHeight)
            .background(configuration.isPressed ? tint : Theme.panel2, in: RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(selected ? tint : (hovering ? tint.opacity(0.8) : tint.opacity(tint == Theme.accent ? 0.0 : 0.35))).padding(0.5))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.line))
            .contentShape(Rectangle())
            .onHover { hovering = $0 }
    }
}

struct MonitorKnob: View {
    let dB: Double?

    var body: some View {
        // Byte 0 of the knob register is attenuation; 0 dB = loudest, ~127 = quietest.
        let fraction = dB.map { max(0, min(1, 1 + $0 / 127)) } ?? 0
        ZStack {
            Circle().trim(from: 0, to: 0.75).stroke(Theme.line, style: .init(lineWidth: Metrics.knobStroke, lineCap: .round))
                .rotationEffect(.degrees(135))
            Circle().trim(from: 0, to: 0.75 * fraction).stroke(Theme.accent, style: .init(lineWidth: Metrics.knobStroke, lineCap: .round))
                .rotationEffect(.degrees(135))
            VStack(spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 3) {   // "−54 dB" on one line
                    Text(dB.map { String(format: "%.0f", $0) } ?? "—")
                        .font(.system(size: Metrics.knobFontSize, weight: .bold, design: .monospaced))
                        .foregroundStyle(Theme.accent)
                    Text("dB")   // styled like the HW KNOB line below
                        .font(.caption.weight(.semibold)).tracking(1).foregroundStyle(Theme.dim)
                }
                Text("HW KNOB").font(.caption2.weight(.semibold)).tracking(2).foregroundStyle(Theme.dim)
            }
        }
        .frame(width: Metrics.knobSize, height: Metrics.knobSize)
    }
}

struct Chip: View {
    let label: String
    let value: String
    var color: Color = Theme.accent

    var body: some View {
        HStack {
            Text(label).foregroundStyle(Theme.dim)
            Spacer()
            Text(value).font(.system(.callout, design: .monospaced).weight(.semibold)).foregroundStyle(color)
        }
        .padding(.horizontal, 14).padding(.vertical, 9)
        .background(Theme.panel2, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.line))
    }
}

// MARK: Fader band

struct MonButton: View {
    let title: String
    let on: Bool
    let color: Color
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: Metrics.monitorButtonFontSize, weight: .heavy)).tracking(1)
                .foregroundStyle(on ? Theme.bg : Theme.dim)
                .frame(maxWidth: .infinity, minHeight: Metrics.monitorButtonHeight)
                .background(on ? color : Theme.panel2, in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(on ? color : Theme.line))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct FaderBand: View {
    let state: MixerState
    let meters: Meters?
    @Binding var target: [Int]
    let model: MixerModel

    private var layoutTargetPair: Int { (target.first ?? 0) / 2 }

    var body: some View {
        let pairs = state.model.mixes / 2
        VStack(alignment: .leading, spacing: 0) {
            // Folder tabs: the selected one opens into the outlined panel below
            HStack(alignment: .bottom, spacing: 0) {   // tabs touch
                ForEach(0..<pairs, id: \.self) { p in
                    HStack(alignment: .bottom, spacing: 0) {
                        if model.monoPairs.contains(p) {
                            tab("Mix \(2 * p + 1)", [2 * p], pair: p)
                            tab("Mix \(2 * p + 2)", [2 * p + 1], pair: p)
                        } else {
                            tab("Mix \(2 * p + 1)/\(2 * p + 2)", [2 * p, 2 * p + 1], pair: p)
                        }
                    }
                    .zIndex(layoutTargetPair == p ? 1 : 0)   // selected tab's outline drawn on top
                }
                Spacer()
                Text("Drag fader · double-click = 0 dB · ⚭ splits or joins").font(.caption).foregroundStyle(Theme.dim)
                    .frame(height: Metrics.mixTabHeight)
            }
            .padding(.leading, Metrics.mixPanelCorner + Metrics.mixTabFlare + 4)   // flare lands on the straight edge
            .zIndex(1)   // the selected tab covers the panel's top border

            // The faders of the selected mix, outlined in the tab's colour
            HStack(spacing: 8) {
                ForEach(0..<(state.inputs.count / 2), id: \.self) { k in
                    let a = state.inputs[2 * k], b = state.inputs[2 * k + 1]
                    let isLinked = model.linked.contains(2 * k)
                    VStack(spacing: 4) {
                    HStack(spacing: 4) {
                        ChannelStrip(state: state, input: a, mixes: target, model: model, linked: isLinked,
                                     level: meterLevel(for: a.source), levelR: meterLevel(for: b.source))
                        if !isLinked {
                            ChannelStrip(state: state, input: b, mixes: target, model: model, linked: false,
                                         level: meterLevel(for: b.source), levelR: 0)
                        }
                    }
                    .frame(maxHeight: .infinity)
                    // Stereo/mono toggle for this pair, inside its box
                    Button { if isLinked { model.linked.remove(2 * k) } else { model.linked.insert(2 * k) } } label: {
                        Text(isLinked ? "⚭ stereo" : "⚭ mono ×2").font(.system(size: Metrics.stereoToggleFontSize, weight: .bold))
                            .foregroundStyle(isLinked ? Theme.accent : Theme.dim)
                            .frame(maxWidth: .infinity, minHeight: Metrics.pairToggleHeight)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help(isLinked ? "Stereo pair: one strip. Click to split into two mono strips"
                                   : "Two mono strips. Click to join into one stereo strip")
                    }
                    .padding(4)
                    .background(Theme.panel2.opacity(0.6), in: RoundedRectangle(cornerRadius: 10))
                }
            }
            .frame(height: Metrics.stripHeight + Metrics.pairToggleHeight + 4)
            .padding(.horizontal, 12).padding(.vertical, 12)
            .background(Theme.mixPanel, in: RoundedRectangle(cornerRadius: Metrics.mixPanelCorner))
            .overlay(RoundedRectangle(cornerRadius: Metrics.mixPanelCorner)
                .stroke(Theme.mixPairColor((target.first ?? 0) / 2), lineWidth: Metrics.mixPanelBorder))
        }
        .padding(.horizontal, 24).padding(.vertical, 14)
    }

    /// A folder tab. Selected: teal outline, open at the bottom, same fill as the panel and
    /// nudged down over the panel's border so the two read as one shape.
    private func tab(_ title: String, _ mixes: [Int], pair p: Int) -> some View {
        let selected = target == mixes
        let mono = model.monoPairs.contains(p)
        let color = Theme.mixPairColor(p)
        return HStack(spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: selected ? .bold : .medium))
                .foregroundStyle(selected ? color : Theme.dim)
            // Stereo/mono icon on the tab: teal = stereo pair, grey = two mono mixes
            Button {
                if mono { model.monoPairs.remove(p); if target.contains(2 * p) || target.contains(2 * p + 1) { target = [2 * p, 2 * p + 1] } }
                else { model.monoPairs.insert(p); if target == [2 * p, 2 * p + 1] { target = [2 * p] } }
            } label: {
                Text("⚭").font(.system(size: Metrics.stereoToggleFontSize + 2, weight: .bold))
                    .foregroundStyle(mono ? Theme.dim : color.opacity(selected ? 1 : 0.6))
                    .frame(width: 18, height: Metrics.mixTabHeight)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(mono ? "Mono: two separate mixes. Click to join into one stereo mix"
                       : "Stereo: one mix. Click to split into two mono mixes")
        }
        .padding(.leading, Metrics.mixTabPadding).padding(.trailing, Metrics.mixTabPadding - 8)
        .frame(height: Metrics.mixTabHeight)
        .background {
            let shape = MixTabShape(radius: Metrics.mixTabCorner, flare: selected ? Metrics.mixTabFlare : 0)
            let flare = selected ? Metrics.mixTabFlare : 0
            let b = Metrics.mixPanelBorder
            ZStack(alignment: .bottom) {
                shape.fill(selected ? Theme.mixPanel : Theme.panel)
                if selected {
                    // Hide the panel's border under the open tab (the flare ends meet it exactly)
                    Rectangle().fill(Theme.mixPanel).frame(height: b * 2).padding(.horizontal, b).offset(y: b)
                }
                if selected {
                    // Glow: a wide, blurred copy of the outline, so it follows the line only (no shadow)
                    shape.stroke(color, lineWidth: Metrics.mixTabGlowWidth)
                        .blur(radius: Metrics.mixTabGlowRadius)
                        .opacity(Metrics.mixTabGlowOpacity)
                }
                shape.stroke(color.opacity(selected ? 1 : Metrics.mixTabIdleOpacity), lineWidth: b)
            }
            .padding(.horizontal, -flare)   // the flare reaches past the tab's sides
        }
        .overlay(alignment: .bottom) {
            // Unselected tabs are shut out of the area: the panel's top border runs under them
            if !selected {
                Rectangle().fill(Theme.mixPairColor(layoutTargetPair)).frame(height: Metrics.mixPanelBorder)
                    .offset(y: Metrics.mixPanelBorder / 2)   // centred on the panel's border line
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { target = mixes }
        .help(selected ? "The faders below set this mix" : "Show this mix's faders")
    }

    private func meterLevel(for source: Source?) -> Double {
        guard let m = meters, let source else { return 0 }
        let raw: UInt16?
        switch source {
        case .analog(let n): raw = m.inputs[safe: n - 1]
        case .spdif(let n): raw = m.inputs[safe: 8 + n - 1]
        case .adat(let n): raw = m.inputs[safe: 10 + n - 1]
        case .daw(let n): raw = m.daw[safe: n - 1]
        default: raw = nil
        }
        guard let raw else { return 0 }
        let db = Meters.dBFS(raw)
        return db.isFinite ? max(0, min(1, (db + 60) / 60)) : 0
    }
}

/// Tab outline: rounded top corners, open at the bottom. With `flare`, the sides curve outward
/// at the base and run into the panel's border line (the rect includes the flare on each side).
struct MixTabShape: Shape {
    var radius: CGFloat
    var flare: CGFloat = 0
    func path(in r: CGRect) -> Path {
        let left = r.minX + flare, right = r.maxX - flare
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.maxY))
        if flare > 0 {
            p.addArc(tangent1End: CGPoint(x: left, y: r.maxY), tangent2End: CGPoint(x: left, y: r.maxY - flare), radius: flare)
        }
        p.addLine(to: CGPoint(x: left, y: r.minY + radius))
        p.addArc(tangent1End: CGPoint(x: left, y: r.minY), tangent2End: CGPoint(x: left + radius, y: r.minY), radius: radius)
        p.addLine(to: CGPoint(x: right - radius, y: r.minY))
        p.addArc(tangent1End: CGPoint(x: right, y: r.minY), tangent2End: CGPoint(x: right, y: r.minY + radius), radius: radius)
        if flare > 0 {
            p.addLine(to: CGPoint(x: right, y: r.maxY - flare))
            p.addArc(tangent1End: CGPoint(x: right, y: r.maxY), tangent2End: CGPoint(x: r.maxX, y: r.maxY), radius: flare)
        } else {
            p.addLine(to: CGPoint(x: right, y: r.maxY))
        }
        return p
    }
}

/// One mixer input (or a linked odd/even pair) in the selected mix.
/// Stereo mix (`mixes` = [L, R]): level + pan (or balance when linked).
/// Mono mix (`mixes` = [m]): level only; a linked pair sends both channels at the same level.
struct ChannelStrip: View {
    let state: MixerState
    let input: MixerInputState
    let mixes: [Int]
    let model: MixerModel
    let linked: Bool
    let level: Double
    let levelR: Double

    @State private var dragStart: Double?
    private static let floor = -60.0, ceiling = 6.0
    private func position(_ dB: Double) -> Double { max(0, min(1, (dB - Self.floor) / (Self.ceiling - Self.floor))) }

    private var i: Int { input.index }
    private var isStereoMix: Bool { mixes.count == 2 }
    private func lin(_ d: Double) -> Double { d <= -128 ? 0 : pow(10, d / 20) }

    private var lp: (Double, Double) {
        if !isStereoMix {
            let m = mixes[0]
            return (linked ? max(model.gain(i, mix: m), model.gain(i + 1, mix: m)) : model.gain(i, mix: m), 0)
        }
        let (mL, mR) = (mixes[0], mixes[1])
        if linked {
            let l = model.gain(i, mix: mL), r = model.gain(i + 1, mix: mR)
            let top = max(l, r)
            guard top > -128 else { return (-128, 0) }
            return (top, l >= r ? -(1 - lin(r) / lin(l)) : (1 - lin(l) / lin(r)))
        }
        return PanLaw.levelPan(model.gain(i, mix: mL), model.gain(i, mix: mR))
    }

    var body: some View {
        let (lvl, pan) = lp
        VStack(spacing: 6) {
            if linked {
                HStack(spacing: 4) { sourceMenu(i, tag: "L"); sourceMenu(i + 1, tag: "R") }
            } else {
                sourceMenu(i, tag: nil)
            }
            if isStereoMix {
                PanRing(value: pan) { setLevel(lvl, pan: $0) }
                    .help(linked ? "Balance: drag around the ring · double-click to centre" : "Pan: drag around the ring · double-click to centre")
            } else {
                Text("MONO").font(.system(size: 8, weight: .bold)).foregroundStyle(Theme.dim).frame(height: 36)
            }
            HStack(spacing: 5) {
                GeometryReader { g in
                    ZStack(alignment: .bottom) {
                        Capsule().fill(Theme.line).frame(width: 4)
                        RoundedRectangle(cornerRadius: 2).fill(Theme.text)
                            .frame(width: Metrics.faderCapSize.width, height: Metrics.faderCapSize.height)
                            .offset(y: -CGFloat(position(lvl)) * (g.size.height - 10))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 0)
                        .onChanged { v in
                            if dragStart == nil { dragStart = lvl }
                            let start = position(max(dragStart ?? lvl, Self.floor))
                            let p = max(0, min(1, start - Double(v.translation.height / max(g.size.height - 10, 1))))
                            setLevel(p <= 0 ? -128 : Self.floor + p * (Self.ceiling - Self.floor), pan: pan)
                        }
                        .onEnded { _ in dragStart = nil })
                    .onTapGesture(count: 2) { setLevel(0, pan: pan) }
                }
                .frame(width: Metrics.faderTrackWidth)
                .padding(.bottom, linked ? 13 : 0)   // line up with the meters' L/R labels
                LEDMeter(level: level, label: linked ? "L" : nil)
                if linked { LEDMeter(level: levelR, label: "R") }
            }
            Text(allOff ? "—" : dbText(lvl)).font(Theme.mono)
            HStack(spacing: 3) {
                small("M", on: model.isMuted(i, mixes: mixes), color: .red) {
                    model.toggleMute(i, mixes: mixes)
                    if linked { model.toggleMute(i + 1, mixes: mixes) }
                }
                small("S", on: model.soloed(mixes) == i, color: Theme.amber) { model.toggleSolo(i, mixes: mixes) }
            }
            Text(linked ? "\(i + 1) · \(i + 2)" : "\(i + 1)").font(.system(size: 9)).foregroundStyle(Theme.dim)
        }
        .padding(.vertical, 8).padding(.horizontal, 2)
        .frame(maxWidth: .infinity)
        .background(Theme.panel, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.line))
        .opacity(allOff ? 0.4 : 1)
    }

    private func setLevel(_ level: Double, pan: Double) {
        if !isStereoMix {
            let m = mixes[0], v = level <= -128 ? -128 : min(6, level)
            model.setGain(input: i, mix: m, dB: v)
            if linked { model.setGain(input: i + 1, mix: m, dB: v) }
            return
        }
        let (mL, mR) = (mixes[0], mixes[1])
        if linked {   // odd input → left, even input → right; balance turns one side down
            func db(_ x: Double) -> Double { level <= -128 || x <= 1e-6 ? -128 : min(6, level + 20 * log10(x)) }
            model.setGain(input: i, mix: mL, dB: db(1 - max(0, pan)))
            model.setGain(input: i, mix: mR, dB: -128)
            model.setGain(input: i + 1, mix: mL, dB: -128)
            model.setGain(input: i + 1, mix: mR, dB: db(1 - max(0, -pan)))
        } else {
            let g = PanLaw.gains(level: level, pan: pan)
            model.setGain(input: i, mix: mL, dB: g.0)
            model.setGain(input: i, mix: mR, dB: g.1)
        }
    }

    private var allOff: Bool {
        input.source == .off && (!linked || state.inputs[safe: i + 1]?.source == .off)
    }

    private func sourceMenu(_ idx: Int, tag: String?) -> some View {
        let src = state.inputs[safe: idx]?.source
        let label = src.flatMap { model.name($0) } ?? (src.map { String(describing: $0) } ?? "?")
            .replacingOccurrences(of: "Analog ", with: "An ").replacingOccurrences(of: "S/PDIF ", with: "SP ")
        return Menu {
            ForEach(Array(Source.all(model: state.model, includeMixes: false).enumerated()), id: \.offset) { _, s in
                Button(String(describing: s)) { model.setMixerInputSource(idx, s) }
            }
        } label: {
            Text("\(tag.map { Text("\($0) ").foregroundStyle(Theme.accent) } ?? Text(""))\(label)")
        }
        .menuStyle(.borderlessButton).menuIndicator(.hidden)
        .font(.system(size: 10, weight: .bold)).lineLimit(1)
        .foregroundStyle(src == .off ? Theme.dim : Theme.text)
    }

    private func small(_ t: String, on: Bool, color: Color, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(t).font(.system(size: 10, weight: .bold))
                .frame(width: Metrics.smallButtonSize.width, height: Metrics.smallButtonSize.height)
                .foregroundStyle(on ? Theme.bg : Theme.dim)
                .background(on ? color : Theme.panel2, in: RoundedRectangle(cornerRadius: 4))
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(on ? color : Theme.line))
        }
        .buttonStyle(.plain)
    }
}

/// Rotary pan/balance: a ring with no pointer; a green arc grows from the top
/// toward the side being panned to, by how far it's panned.
struct PanRing: View {
    let value: Double            // −1 (left) … +1 (right)
    let onChange: (Double) -> Void
    var body: some View {
        let sweep = 0.375 * abs(value)          // up to 135° each way
        ZStack {
            Circle().trim(from: 0, to: 0.75)
                .stroke(Theme.line, style: .init(lineWidth: Metrics.panRingStroke, lineCap: .round))
                .rotationEffect(.degrees(135))
            Circle().trim(from: value < 0 ? 0.375 - sweep : 0.375, to: value < 0 ? 0.375 : 0.375 + sweep)
                .stroke(Color.green, style: .init(lineWidth: Metrics.panRingStroke, lineCap: .round))
                .rotationEffect(.degrees(135))
                .shadow(color: .green.opacity(0.6), radius: 3)
            // Centre notch: always visible, lit when centred
            Capsule().fill(abs(value) < 0.02 ? Color.green : Theme.dim)
                .frame(width: 2, height: 6)
                .offset(y: -18)
        }
        .frame(width: Metrics.panRingSize, height: Metrics.panRingSize)
        .padding(.top, 6)
        .contentShape(Rectangle())
        .gesture(DragGesture(minimumDistance: 1)
            .onChanged { v in
                // Knob-style: pan follows the pointer's angle around the ring centre.
                // Top = centre; going down the left side pans further left, right side further right.
                let dx = Double(v.location.x - 15), dy = Double(v.location.y - 21)
                guard dx * dx + dy * dy > 4 else { return }
                let degrees = atan2(dx, -dy) * 180 / .pi            // 0 at top, ±180 at bottom
                let v2 = max(-1, min(1, degrees / 135))
                onChange(abs(v2) < 0.06 ? 0 : v2)                   // detent at centre
            })
        .onTapGesture(count: 2) { onChange(0) }
    }
}

struct LEDMeter: View {
    let level: Double
    var label: String? = nil
    var body: some View {
        let lit = Int((level * Double(Metrics.meterSegments)).rounded())
        VStack(spacing: 3) {
            VStack(spacing: 2) {
                ForEach((0..<Metrics.meterSegments).reversed(), id: \.self) { k in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(k < lit ? segmentColor(k) : segmentColor(k).opacity(Metrics.meterUnlitOpacity))
                }
            }
            if let label {
                Text(label).font(.system(size: 8, weight: .bold)).foregroundStyle(Theme.dim).frame(height: 10)
            }
        }
        .frame(width: Metrics.meterWidth)
    }

    /// Colour by the dB value a segment represents: teal, amber near the top, red close to clipping.
    private func segmentColor(_ k: Int) -> Color {
        let step = -Metrics.meterFloorDB / Double(Metrics.meterSegments)
        let top = Metrics.meterFloorDB + Double(k + 1) * step     // upper edge of this segment, in dBFS
        if top > Metrics.meterClipDB { return Theme.clip }
        if top > Metrics.meterWarnDB { return Theme.amber }
        return Theme.accent
    }
}

// MARK: Outputs

/// One row per output pair with a single dropdown: a mix (blended) or one source only.
/// Matches the hardware: each output plays exactly one source.
struct OutputsList: View {
    let state: MixerState
    let model: MixerModel

    private struct Choice: Hashable { let title: String; let left: Source; let right: Source }

    private var mixChoices: [Choice] {
        (0..<(state.model.mixes / 2)).flatMap { p -> [Choice] in
            if model.monoPairs.contains(p) {
                return [Choice(title: "Mix \(2 * p + 1) (mono)", left: .mix(2 * p), right: .mix(2 * p)),
                        Choice(title: "Mix \(2 * p + 2) (mono)", left: .mix(2 * p + 1), right: .mix(2 * p + 1))]
            }
            return [Choice(title: "Mix \(2 * p + 1)/\(2 * p + 2)", left: .mix(2 * p), right: .mix(2 * p + 1))]
        }
    }

    private var directChoices: [Choice] {
        let o = state.model.sourceOffsets
        func pairs(_ count: Int, _ name: String, _ make: (Int) -> Source) -> [Choice] {
            stride(from: 1, to: count, by: 2).map { Choice(title: "\(name) \($0)/\($0 + 1)", left: make($0), right: make($0 + 1)) }
        }
        return pairs(o.spdif - o.analog, "Input", { .analog($0) })
            + pairs(o.adat - o.spdif, "S/PDIF", { .spdif($0) })
            + pairs(o.mix - o.adat, "ADAT", { .adat($0) })
            + pairs(o.analog - o.pcm, "DAW", { .daw($0) })
    }

    private func label(_ l: Source?, _ r: Source?) -> (String, Bool) {
        guard let l, let r else { return ("?", false) }
        if l == .off && r == .off { return ("Off", false) }
        if let c = mixChoices.first(where: { $0.left == l && $0.right == r }) { return (c.title, false) }
        if let c = directChoices.first(where: { $0.left == l && $0.right == r }) { return (c.title, true) }
        return ("L: \(l) · R: \(r)", false)
    }

    private func outputName(_ o: OutputPairState) -> String {
        guard state.model == .scarlett18i20 else { return o.name }
        switch o.name {
        case "Monitor": return "Monitor 1/2"
        case "Line 7/8": return "Line 7/8 · Phones 1"
        case "Line 9/10": return "Line 9/10 · Phones 2"
        default: return o.name
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("OUTPUTS · each output plays one thing: a mix, or a single source")
                .font(.caption2.weight(.bold)).tracking(2).foregroundStyle(Theme.dim)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 24), GridItem(.flexible(), spacing: 24)], spacing: 8) {
                ForEach(state.outputs) { o in
                    let (title, only) = label(o.left.source, o.right.source)
                    HStack {
                        Text(outputName(o)).font(.system(.callout, design: .monospaced))
                        Spacer()
                        Menu {
                            Section("Mixes (blended)") {
                                ForEach(mixChoices, id: \.self) { c in Button(c.title) { set(o.index, c) } }
                            }
                            Section("Only one source (no mixing)") {
                                ForEach(directChoices, id: \.self) { c in Button(c.title) { set(o.index, c) } }
                            }
                            Divider()
                            Button("Off") { set(o.index, Choice(title: "Off", left: .off, right: .off)) }
                        } label: {
                            HStack(spacing: 6) {
                                Text(title).foregroundStyle(title == "Off" ? Theme.dim : (only ? Theme.amber : Theme.accent))
                                if only { Text("· only").foregroundStyle(Theme.amber.opacity(0.7)) }
                            }
                            .font(.system(.callout, design: .monospaced).weight(.semibold))
                        }
                        .menuStyle(.borderlessButton)
                        .fixedSize()
                    }
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .background(Theme.panel, in: RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.line))
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24).padding(.vertical, 14)
    }

    private func set(_ pair: Int, _ c: Choice) {
        model.setOutputSource(2 * pair, c.left)
        model.setOutputSource(2 * pair + 1, c.right)
    }
}

// MARK: Patch bay

struct PatchBay: View {
    let state: MixerState
    let model: MixerModel
    /// Last plain-clicked cell (output row, source column); shift-click fills the range from it.
    @State private var anchor: (row: Int, col: Int)?
    @State private var renaming: Source?
    @State private var draft = ""
    /// Cell under the pointer (output row, source column): drives the header readout and label highlight.
    @State private var hovered: (row: Int, col: Int)?
    /// Box selection: drag a rectangle to turn off the lit cells inside it.
    @State private var cellFrames: [CellID: CGRect] = [:]
    @State private var boxStart: CGPoint?
    @State private var boxRect: CGRect?
    /// Set by the first cell under the drag: clear lit cells, or route that column's source.
    private enum BoxMode: Equatable { case clear, route(col: Int) }
    @State private var boxMode: BoxMode?

    private var columns: [Source] {
        (0..<state.model.mixes).map { .mix($0) } + (1...8).map { .analog($0) } + (1...8).map { .daw($0) }
    }

    var body: some View {
        let outputs: [(String, Source?)] = state.outputs.flatMap { o in
            [("\(o.name) L", o.left.source), ("\(o.name) R", o.right.source)]
        }
        VStack(alignment: .leading, spacing: 8) {
            Group {
                if let h = hovered, let out = outputs[safe: h.row], let src = columns[safe: h.col] {
                    routeText(out.0, " ← ", longName(src), groupBright(src))
                        .font(.system(.caption, design: .monospaced).weight(.semibold))
                } else {
                    Text("OUTPUTS ← SOURCES   (click to route · click lit cell for off · shift-click to fill the column down/up)")
                        .font(.caption2.weight(.bold)).tracking(2).foregroundStyle(Theme.dim)
                }
            }
            .frame(height: 14, alignment: .leading)
            FitOrScroll {
                matrixGrid(outputs)
                    .coordinateSpace(name: "matrix")
                    .onPreferenceChange(CellFramesKey.self) { cellFrames = $0 }
                    .gesture(DragGesture(minimumDistance: 6, coordinateSpace: .named("matrix"))
                        .onChanged { v in
                            if boxStart == nil {
                                boxStart = v.startLocation
                                if let start = cellFrames.first(where: { $0.value.contains(v.startLocation) })?.key {
                                    let lit = outputs[safe: start.row]?.1 == columns[safe: start.col]
                                    boxMode = lit ? .clear : .route(col: start.col)
                                } else {
                                    boxMode = .clear
                                }
                            }
                            let a = boxStart ?? v.startLocation, b = v.location
                            boxRect = CGRect(x: min(a.x, b.x), y: min(a.y, b.y), width: abs(a.x - b.x), height: abs(a.y - b.y))
                        }
                        .onEnded { _ in
                            if let box = boxRect {
                                switch boxMode {
                                case .route(let col)?: routeBox(box, col: col)
                                default: clearBox(box, outputs: outputs)
                                }
                            }
                            boxStart = nil; boxRect = nil; boxMode = nil
                        })
                    .overlay(alignment: .topLeading) {
                        if let b = boxRect {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(boxColor.opacity(0.08))
                                .overlay(RoundedRectangle(cornerRadius: 3).stroke(boxColor.opacity(0.8), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])))
                                .frame(width: b.width, height: b.height)
                                .offset(x: b.minX, y: b.minY)
                                .allowsHitTesting(false)
                        }
                    }
            }
        }
        .padding(.horizontal, 24).padding(.vertical, 14)
    }

    private var boxColor: Color {
        if case .route(let col)? = boxMode, let src = columns[safe: col] { return groupBright(src) }
        return Theme.clip
    }

    /// Routes the start column's source to every output row the box covers.
    private func routeBox(_ box: CGRect, col: Int) {
        guard let src = columns[safe: col] else { return }
        let rows = Set(cellFrames.filter { box.intersects($0.value) }.map(\.key.row))
        for row in rows.sorted() { model.setOutputSource(row, src) }
    }

    /// Turns off every lit cell inside the box (outputs whose current source column is in it).
    private func clearBox(_ box: CGRect, outputs: [(String, Source?)]) {
        let inside = cellFrames.filter { box.intersects($0.value) }.map(\.key)
        for row in Set(inside.map(\.row)) {
            guard let current = outputs[safe: row]?.1, current != .off,
                  let col = columns.firstIndex(of: current), inside.contains(CellID(row: row, col: col)) else { continue }
            model.setOutputSource(row, .off)
        }
    }

    @ViewBuilder
    private func matrixGrid(_ outputs: [(String, Source?)]) -> some View {
                Grid(horizontalSpacing: Metrics.matrixSpacing, verticalSpacing: Metrics.matrixSpacing) {
                    GridRow {
                        Text("")
                        groupHeader("MIXES", count: state.model.mixes, color: Theme.accent)
                        groupHeader("INPUTS", count: 8, color: Theme.amber)
                        groupHeader("DAW (COMPUTER PLAYBACK)", count: 8, color: Theme.blue)
                        Text("")
                    }
                    GridRow {
                        Text("")
                        ForEach(Array(columns.enumerated()), id: \.offset) { ci, s in
                            columnLabel(s, hot: hovered?.col == ci)
                                .padding(.horizontal, 4).padding(.vertical, 1)
                                .background(hovered?.col == ci ? groupColor(s).opacity(0.35) : .clear, in: RoundedRectangle(cornerRadius: 3))
                        }
                        Text("other").font(.system(size: 9)).foregroundStyle(Theme.dim)
                    }
                    ForEach(Array(outputs.enumerated()), id: \.offset) { n, out in
                        GridRow {
                            rowLabel(n, out)
                            ForEach(Array(columns.enumerated()), id: \.offset) { ci, src in
                                matrixCell(row: n, col: ci, source: src, output: out)
                            }
                            Text(otherText(out.1)).font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(Theme.dim).frame(width: 70, alignment: .leading)
                        }
                    }
                }
    }

    /// An output's name at the start of its row, highlighted while its row is hovered.
    private func rowLabel(_ n: Int, _ out: (String, Source?)) -> some View {
        let rowHot: Bool = hovered?.row == n
        let hotSource: Source? = hovered.flatMap { columns[safe: $0.col] }
        let textColor: Color = rowHot ? (hotSource.map(groupBright) ?? Theme.text) : routedTint(out.1)
        let fill: Color = rowHot ? (hotSource.map { groupColor($0).opacity(0.35) } ?? .clear) : .clear
        return Text(out.0).font(.system(size: 11, design: .monospaced))
            .foregroundStyle(textColor)
            .padding(.horizontal, 4).padding(.vertical, 1)
            .background(fill, in: RoundedRectangle(cornerRadius: 3))
            .frame(width: 120, alignment: .leading)
    }

    /// One patch-bay cell: lit when this output plays this source. (Kept separate, with
    /// explicit types, so older compilers can type-check the matrix in reasonable time.)
    private func matrixCell(row n: Int, col ci: Int, source s: Source, output out: (String, Source?)) -> some View {
        let on: Bool = out.1 == s
        let isHovered: Bool = hovered.map { $0.row == n && $0.col == ci } ?? false
        let fill: Color = on ? groupBright(s) : groupColor(s).opacity(0.07)
        let glow: Color = on ? groupBright(s).opacity(0.8) : .clear
        let id = CellID(row: n, col: ci)
        let inBox: Bool = boxRect.map { b in cellFrames[id].map { b.intersects($0) } ?? false } ?? false
        let boxStroke: Color = inBox ? boxColor.opacity(0.8) : .clear
        let isAnchor: Bool = anchor.map { $0.row == n && $0.col == ci } ?? false
        let anchorStroke: Color = isAnchor ? Theme.accent.opacity(0.6) : .clear
        return RoundedRectangle(cornerRadius: 3)
            .fill(fill)
            .shadow(color: glow, radius: 5)
            .frame(height: Metrics.matrixCellHeight)
            .contentShape(Rectangle())
            .onHover { inside in
                if inside { hovered = (n, ci) }
                else if hovered.map({ $0.row == n && $0.col == ci }) == true { hovered = nil }
            }
            .overlay(alignment: .bottom) {
                if isHovered { cellTooltip(output: out.0, source: s) }
            }
            .zIndex(isHovered ? 1 : 0)
            .overlay(RoundedRectangle(cornerRadius: 3).stroke(boxStroke, lineWidth: 1))
            .background(GeometryReader { g in
                Color.clear.preference(key: CellFramesKey.self, value: [id: g.frame(in: .named("matrix"))])
            })
            .overlay(RoundedRectangle(cornerRadius: 3).stroke(anchorStroke))
            .onTapGesture { tap(row: n, col: ci, lit: on) }
    }

    private func tap(row: Int, col: Int, lit: Bool) {
        if NSEvent.modifierFlags.contains(.shift), let a = anchor {
            // Vertical fill: route the anchor's source to every output between the anchor row and this row.
            for r in min(a.row, row)...max(a.row, row) { model.setOutputSource(r, columns[a.col]) }
        } else {
            model.setOutputSource(row, lit ? .off : columns[col])
            anchor = (row, col)
        }
    }

    @ViewBuilder
    private func columnLabel(_ s: Source, hot: Bool = false) -> some View {
        let renamable: Bool = { if case .mix = s { return false }; return true }()
        Text(model.name(s) ?? short(s))
            .font(.system(size: 9, design: .monospaced)).foregroundStyle(hot ? groupBright(s) : groupColor(s))
            .lineLimit(1).truncationMode(.tail)
            .help(longName(s) + (renamable ? " · click to rename" : ""))
            .onTapGesture {
                guard renamable else { return }
                draft = model.name(s) ?? ""
                renaming = s
            }
            .contextMenu { ForEach(info(s), id: \.self) { Text($0) } }
            .popover(isPresented: Binding(get: { renaming == s }, set: { if !$0 { renaming = nil } })) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Rename \(short(s))").font(.headline)
                    TextField(short(s), text: $draft)
                        .textFieldStyle(.roundedBorder).frame(width: 180)
                        .onSubmit { model.rename(s, draft); renaming = nil }
                    HStack {
                        Button("Reset") { model.rename(s, ""); renaming = nil }
                        Spacer()
                        Button("Save") { model.rename(s, draft); renaming = nil }.keyboardShortcut(.defaultAction)
                    }
                }
                .padding()
            }
    }

    /// Lines for the right-click info card about a source column.
    private func info(_ s: Source) -> [String] {
        var lines: [String] = []
        switch s {
        case .analog(let n): lines.append("Analog input \(n) (jack \(n) on the 18i20)")
        case .daw(let n): lines.append("DAW \(n) (computer playback channel \(n))")
        case .mix(let n): lines.append("Mix \(n + 1) (\(n % 2 == 0 ? "left" : "right") side of Mix \(n / 2 * 2 + 1)/\(n / 2 * 2 + 2))")
        default: lines.append("\(s)")
        }
        if let custom = model.name(s) { lines.append("Name: \(custom)") }

        let outs = state.outputs.flatMap { o -> [String] in
            var r: [String] = []
            if o.left.source == s { r.append("\(o.name) L") }
            if o.right.source == s { r.append("\(o.name) R") }
            return r
        }
        lines.append(outs.isEmpty ? "Not played directly by any output" : "Played by: " + outs.joined(separator: ", "))

        if case .mix(let m) = s {
            let inMix = state.inputs.filter { ($0.gains[safe: m] ?? nil).map { $0 > -128 } == true && $0.source != .off }
                .map { "\($0.index + 1) (\(model.name($0.source!) ?? String(describing: $0.source!)))" }
            lines.append(inMix.isEmpty ? "Nothing audible in this mix" : "Audible channels: " + inMix.joined(separator: ", "))
        } else {
            let chans = state.inputs.filter { $0.source == s }.map { "\($0.index + 1)" }
            lines.append(chans.isEmpty ? "Not on any mixer channel" : "On mixer channel " + chans.joined(separator: ", "))
        }
        return lines
    }

    private func groupHeader(_ title: String, count: Int, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(title).font(.system(size: 9, weight: .bold)).tracking(1.5).foregroundStyle(color)
            Rectangle().fill(color.opacity(0.5)).frame(height: 1)
        }
        .gridCellColumns(count)
    }

    /// Row label colour: the hue of what the output plays (mix / input / DAW), plain when Off.
    private func routedTint(_ s: Source?) -> Color {
        switch s {
        case .mix?, .analog?, .daw?: groupColor(s!)
        case .off?, nil: Theme.dim              // nothing routed: dimmed
        default: Theme.text.opacity(0.75)       // S/PDIF, ADAT, DAW 9+ (not in the columns)
        }
    }

    /// "Output ← source", with the source in its group's colour. (Kept separate: inline, this
    /// is too much for older compilers to type-check inside the matrix.)
    private func routeText(_ output: String, _ arrow: String, _ source: String, _ color: Color) -> Text {
        let o: Text = Text(output).foregroundStyle(Theme.text)
        let a: Text = Text(arrow).foregroundStyle(Theme.dim)
        let s: Text = Text(source).foregroundStyle(color)
        return Text("\(o)\(a)\(s)")
    }

    /// The small tooltip shown at a hovered matrix cell.
    private func cellTooltip(output: String, source: Source) -> some View {
        routeText(output, " ← ", model.name(source) ?? short(source), groupBright(source))
            .font(.system(size: 11, weight: .semibold, design: .monospaced))
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(Theme.panel2, in: RoundedRectangle(cornerRadius: 5))
            .overlay(RoundedRectangle(cornerRadius: 5).stroke(Theme.line))
            .fixedSize()
            .offset(y: -Metrics.matrixCellHeight - 6)
            .allowsHitTesting(false)
    }

    /// Lit-dot colour: a brighter version of the group's hue.
    private func groupBright(_ s: Source) -> Color {
        switch s {
        case .mix: Theme.mixBright
        case .analog: Theme.analogBright
        default: Theme.dawBright
        }
    }

    private func groupColor(_ s: Source) -> Color {
        switch s {
        case .mix: Theme.accent
        case .analog: Theme.amber
        default: Theme.blue
        }
    }

    private func longName(_ s: Source) -> String {
        switch s {
        case .mix(let n):
            let pair = n / 2
            return "Mix \(n + 1) (\(n % 2 == 0 ? "left" : "right") side of Mix \(2 * pair + 1)/\(2 * pair + 2))"
        case .analog(let n): return (model.name(s).map { "\($0) — " } ?? "") + "Analog input \(n), sent straight to the output"
        case .daw(let n): return (model.name(s).map { "\($0) — " } ?? "") + "DAW \(n) (computer playback), sent straight to the output"
        default: return "\(s)"
        }
    }

    private func short(_ s: Source) -> String {
        switch s {
        case .mix(let n): "Mix\(n + 1)"
        case .analog(let n): "In\(n)"
        case .daw(let n): "DAW\(n)"
        default: "?"
        }
    }

    private func otherText(_ s: Source?) -> String {
        guard let s else { return "?" }
        if s == .off { return "off" }
        return columns.contains(s) ? "" : "\(s)"
    }
}

/// Shows content as-is when it fits; wraps it in a scroll view only when it doesn't.
struct FitOrScroll<Content: View>: View {
    @ViewBuilder let content: () -> Content
    var body: some View {
        ViewThatFits(in: .vertical) {
            content()
            ScrollView { content() }
        }
    }
}

struct CellID: Hashable { let row: Int; let col: Int }

struct CellFramesKey: PreferenceKey {
    static let defaultValue: [CellID: CGRect] = [:]
    static func reduce(value: inout [CellID: CGRect], nextValue: () -> [CellID: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

extension Array {
    subscript(safe i: Int) -> Element? { indices.contains(i) ? self[i] : nil }
}

#Preview {
    ContentView(model: MixerModel(), layout: LayoutState())
}
