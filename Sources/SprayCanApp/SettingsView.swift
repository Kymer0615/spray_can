import AppKit
import SwiftUI
import Combine
import ServiceManagement
import SprayCanCore

struct SettingsView: View {
    @ObservedObject var controller: AppController
    @ObservedObject private var settings = Settings.shared
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @State private var permissionRevision = 0
    @State private var loginEnabled = SMAppService.mainApp.status == .enabled
    @State private var loginError = ""
    @State private var tab = "General"
    private let height: CGFloat
    init(controller: AppController, initialTab: String = "General", height: CGFloat = 540) {
        self.controller = controller; self.height = height
        _tab = State(initialValue: initialTab)
    }
    private let timer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()
    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    SprayCanMark().stroke(.teal, style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round)).frame(width: 30, height: 40)
                    VStack(alignment: .leading) { Text("Spray Can").font(.headline); Text("Point. Type. Click.").font(.caption).foregroundStyle(.secondary) }
                }.padding(.bottom, 24).padding(.top, 10)
                ForEach(["General", "Apps", "Shortcuts", "Appearance", "Permissions", "About"], id: \.self) { item in
                    Button { tab = item } label: {
                        Label(LocalizedStringKey(item), systemImage: icon(item)).frame(maxWidth: .infinity, alignment: .leading).padding(10)
                            .background(tab == item ? Color.teal.opacity(0.15) : .clear, in: RoundedRectangle(cornerRadius: 9))
                    }.buttonStyle(.plain)
                }
                Spacer()
                Text("Your keyboard, everywhere.").font(.caption).foregroundStyle(.secondary)
            }.padding(20).frame(width: 205).background(.ultraThinMaterial)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text(LocalizedStringKey(tab)).font(.system(size: 28, weight: .bold))
                    content
                }.padding(30).frame(maxWidth: .infinity, alignment: .leading)
            }.frame(width: 490).background(Color(nsColor: .windowBackgroundColor))
        }.frame(height: height)
            .onReceive(timer) { _ in permissionRevision += 1 }
            .onReceive(controller.$requestedTab.compactMap { $0 }) { requested in tab = requested; controller.requestedTab = nil }
    }
    private func icon(_ name: String) -> String {
        ["General":"cursorarrow.motionlines", "Apps":"square.grid.2x2", "Shortcuts":"keyboard", "Appearance":"paintpalette", "Permissions":"hand.raised", "About":"info.circle"][name] ?? "circle"
    }
    @ViewBuilder private var content: some View {
        switch tab {
        case "General":
            Text("Reach your Mac without reaching for the mouse.").foregroundStyle(.secondary)
            section("Clicking") {
                Toggle("Click as soon as a label is complete", isOn: $settings.instantClick)
                Text("By default, labels move the pointer. Return clicks.").font(.caption).foregroundStyle(.secondary)
                Toggle("Press Return twice to double-click", isOn: $settings.returnTwiceDoubleClicks)
                Text("Within your Mac’s double-click speed after a click. Any other key goes to the app as usual.").font(.caption).foregroundStyle(.secondary)
                Toggle("Hold Return to right-click", isOn: $settings.holdReturnRightClicks)
                Text("Return then clicks when released; holding it about half a second right-clicks.").font(.caption).foregroundStyle(.secondary)
            }
            section("Keyboard") {
                Toggle("Let macOS shortcuts work during navigation", isOn: $settings.passSystemShortcuts)
                Text("⌘ and ⌃ shortcuts that Spray Can doesn’t use — copy, paste, close window, Spotlight — go to macOS and apps.").font(.caption).foregroundStyle(.secondary)
                Button("Edit shortcuts…") { tab = "Shortcuts" }.buttonStyle(.link)
            }
            section("Targets") {
                Toggle("Include all visible windows", isOn: $settings.allWindows)
                Toggle("Use on-device text recognition", isOn: $settings.vision)
                Text("Find text that apps don’t expose to accessibility. OCR labels mark text locations, which may not be clickable. Requires Screen Recording. Images stay in memory on this Mac.").font(.caption).foregroundStyle(.secondary)
                if settings.vision {
                    Toggle("Hide text labels on known elements", isOn: $settings.dedupeOCR)
                    Text("Skip recognized text that an element label already marks, such as a button’s title.").font(.caption).foregroundStyle(.secondary)
                    Toggle("Prepare text labels in advance", isOn: $settings.prescanText)
                    Text("Reads the focused window about a second after you switch to it, only when connected to power. Text labels then appear at once.").font(.caption).foregroundStyle(.secondary)
                    ocrLanguages
                }
            }
            section("Scrolling") {
                VStack(alignment: .leading) {
                    Text(settings.scrollSmoothness < 0.01 ? String(localized: "Scroll smoothness · Off") : String(localized: "Scroll smoothness · \(Int((settings.scrollSmoothness * 100).rounded()))%"))
                    Slider(value: $settings.scrollSmoothness, in: 0...1, step: 0.05)
                }
                Picker("Pointer in scroll mode", selection: $settings.scrollPointer) {
                    ForEach(ScrollPointerPlacement.allCases, id: \.self) { Text(pointerTitle($0)).tag($0) }
                }
                Text("Scroll events go to the pointer. Don’t move scrolls what’s under it; other choices move it into the area until scroll mode ends.").font(.caption).foregroundStyle(.secondary)
            }
            section("App") {
                Picker("Language", selection: $settings.appLanguage) {
                    Text("System default").tag(String?.none)
                    ForEach(AppLanguage.options, id: \.code) { Text(verbatim: $0.name).tag(Optional($0.code)) }
                }
                if settings.appLanguage != settings.launchLanguage {
                    HStack {
                        Text("Restart Spray Can to use the new language.").font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Button("Restart Now") { AppLanguage.relaunch() }
                    }
                }
                Toggle("Launch at login", isOn: $loginEnabled).onChange(of: loginEnabled) { _, value in
                    do { if value { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }; loginError = "" }
                    catch { loginError = error.localizedDescription }
                }
                if !loginError.isEmpty { Text(loginError).font(.caption).foregroundStyle(.red) }
            }
        case "Apps":
            Text("Choose text recognition and scan time for individual apps. Other apps follow General.").foregroundStyle(.secondary)
            if settings.appProfiles.isEmpty {
                Text("No app settings yet. Add an app, or use This App in the menu bar while you work in it.").font(.callout).foregroundStyle(.secondary)
            }
            ForEach(settings.appProfiles.keys.sorted { (settings.appProfiles[$0]?.name ?? $0).localizedCaseInsensitiveCompare(settings.appProfiles[$1]?.name ?? $1) == .orderedAscending }, id: \.self) { id in
                appRow(id)
            }
            Menu("Add App") {
                ForEach(AppProfileCandidates.running(excluding: Set(settings.appProfiles.keys)), id: \.id) { app in
                    Button(app.name) { settings.updateProfile(app.id, name: app.name) { _ in } }
                }
            }.fixedSize()
            Text("Scan time Extended gives slow apps such as Finder and System Settings longer to report their controls.").font(.caption).foregroundStyle(.secondary)
            AppAnalysisSection(analyzer: controller.analyzer)
        case "Shortcuts":
            Text("Use a modifier with a letter or number. Click a shortcut to record a new one. Escape cancels recording.").foregroundStyle(.secondary)
            ForEach(NavigationMode.allCases, id: \.self) { mode in
                HStack {
                    Text(mode.localizedTitle); Spacer()
                    ShortcutRecorder(shortcut: Binding(get: { settings.shortcuts[mode] ?? Shortcut.defaults[mode]! }, set: { settings.shortcuts[mode] = $0 })).frame(width: 135, height: 30)
                }
            }
            Toggle("Use vi cursor bindings", isOn: $settings.vi)
            Text("Vi mode reserves HJKL for movement and removes them from labels. Label letters always use physical US key positions, including when an IME is active.").font(.caption).foregroundStyle(.secondary)
            ForEach(controller.shortcutIssues, id: \.self) { Text($0).foregroundStyle(.red).font(.caption) }
            Button("Restore default shortcuts") { settings.shortcuts = Shortcut.defaults }
            Text("Return: left click · [: middle click · ]: right click\n\\: double-click · =: hold left button · Return: drop\n⇧ arrows: scroll · ⌘H: hide · ⌘,: settings").font(.system(.caption, design: .monospaced)).lineSpacing(7)
        case "Appearance":
            Text("Quiet visuals. Clear destinations.").foregroundStyle(.secondary)
            AppearancePreview().frame(height: 100)
            section("Labels") {
                Toggle("Use Liquid Glass", isOn: $settings.glassEnabled)
                VStack(alignment: .leading) { Text("Label size · \(Int(settings.fontSize)) pt"); Slider(value: $settings.fontSize, in: 10...22, step: 1) }
                Picker("Label position", selection: $settings.hintPosition) {
                    ForEach(HintPosition.allCases, id: \.self) { Text(positionTitle($0)).tag($0) }
                }
                VStack(alignment: .leading) { Text("Horizontal offset · \(Int(settings.hintOffsetX)) pt"); Slider(value: $settings.hintOffsetX, in: -40...40, step: 1) }
                VStack(alignment: .leading) { Text("Vertical offset · \(Int(settings.hintOffsetY)) pt"); Slider(value: $settings.hintOffsetY, in: -40...40, step: 1) }
                VStack(alignment: .leading) {
                    Text(reduceTransparency ? "Label background opacity · Opaque" : settings.glassEnabled ? "Label background opacity · System managed" : "Label background opacity · \(Int(settings.contrast * 100))%")
                    Slider(value: $settings.contrast, in: 0.4...1).disabled(settings.glassEnabled || reduceTransparency)
                }
                Text("Labels sit beside their element’s text. Opacity applies to plain backgrounds; glass and Reduce Transparency manage it for you.").font(.caption).foregroundStyle(.secondary)
                Button("Restore label placement") { settings.restoreHintPlacement() }
            }
            section("Color coding") {
                Toggle("Color-code labels", isOn: $settings.colorCodeTargets)
                Text("Nearby labels get clearly different colors. While you type, the matching elements are outlined in their label’s color.").font(.caption).foregroundStyle(.secondary)
                if settings.colorCodeTargets {
                    Text("Color scheme").font(.subheadline.weight(.semibold))
                    ForEach(LabelColorScheme.all) { scheme in schemeRow(scheme) }
                    Picker("Shade elements", selection: $settings.elementShading) {
                        ForEach(ElementShading.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                    if settings.elementShading != .off {
                        VStack(alignment: .leading) {
                            Text("Shading opacity · \(Int((settings.shadingOpacity * 100).rounded()))%")
                            Slider(value: $settings.shadingOpacity, in: 0.05...0.5, step: 0.01)
                        }
                    }
                    Button("Restore color coding") { settings.restoreShading() }
                }
            }
            section("Colors") {
                // Color coding replaces the label colors; they still apply to grid labels.
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 18), GridItem(.flexible(), spacing: 18)], alignment: .leading, spacing: 10) {
                    ForEach(settings.colorCodeTargets ? [AppearanceColor.grid, .highlight] : AppearanceColor.allCases, id: \.self) { colorPicker($0) }
                }
                if settings.colorCodeTargets {
                    DisclosureGroup("Plain label colors (grid mode)") {
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 18), GridItem(.flexible(), spacing: 18)], alignment: .leading, spacing: 10) {
                            ForEach([AppearanceColor.label, .ocr, .text], id: \.self) { colorPicker($0) }
                        }.padding(.top, 6)
                    }
                }
                Button("Restore default colors") { settings.restoreColors() }
            }
            section("Grid") {
                VStack(alignment: .leading) { Text("Grid cell size · \(Int(settings.cellSize)) pt"); Slider(value: $settings.cellSize, in: 32...240, step: 4) }
            }
        case "Permissions":
            Text("Only the access needed to navigate.").foregroundStyle(.secondary)
            permission("Accessibility", id: "accessibility", detail: "Find controls and move, click, drag, and scroll.", granted: controller.accessibilityGranted, action: controller.requestAccessibility)
            LabeledContent("Keyboard capture", value: controller.keyboardReady ? String(localized: "Ready") : String(localized: "Not running"))
            Text("Keyboard capture uses Accessibility access. Screen Recording is separate and only needed for OCR.").font(.caption).foregroundStyle(.secondary)
            permission("Screen Recording", id: "screen", detail: "Optional. Find text from an on-demand screenshot.", granted: controller.screenGranted, action: controller.requestScreen)
            Button("Retry keyboard capture") { controller.start() }.buttonStyle(.borderedProminent).tint(.teal)
            Text(controller.status).font(.caption).foregroundStyle(.secondary)
            Text("After changing macOS permissions, a relaunch may be needed. Another tool using these shortcuts can cause conflicts; quit Scoot or change its bindings.").font(.caption).foregroundStyle(.secondary)
        default:
            SprayCanMark().stroke(.teal, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)).frame(width: 66, height: 88)
            Text("Spray Can \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Development")").font(.title2.bold())
            Text("Keyboard-driven navigation, built for your Mac. Free and open source under the MIT License.").foregroundStyle(.secondary)
            Link("Source, releases & documentation ↗", destination: URL(string: "https://github.com/Kymer0615/spray_can")!)
            Link(destination: URL(string: "https://buymeacoffee.com/ziyang")!) {
                HStack(spacing: 8) {
                    Image("BuyMeACoffee").resizable().scaledToFit().frame(width: 24, height: 24)
                    Text("Buy me a coffee")
                }.padding(.vertical, 8).padding(.horizontal, 12)
                    .foregroundStyle(.black).background(Color(red: 1, green: 0.87, blue: 0), in: RoundedRectangle(cornerRadius: 9))
            }.accessibilityLabel("Buy me a coffee — support Ziyang")
            Text("No analytics. No cloud inference. No saved screenshots. Diagnostics contain timings and counts, not typed labels or captured screen content.").font(.caption).foregroundStyle(.secondary)
            Text("MIT License · © 2026 Spray Can contributors").font(.caption2).foregroundStyle(.secondary)
        }
    }
    /// One app's overrides; Same as General shows what the global setting currently is.
    private func appRow(_ id: String) -> some View {
        let profile = settings.appProfiles[id] ?? AppProfile(name: id)
        let behavior = settings.behavior(for: id)
        func binding<Value>(_ path: WritableKeyPath<AppProfile, Value>) -> Binding<Value> {
            Binding(get: { profile[keyPath: path] }, set: { value in settings.updateProfile(id, name: profile.name) { $0[keyPath: path] = value } })
        }
        return GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Image(nsImage: AppProfileCandidates.icon(for: id)).resizable().frame(width: 28, height: 28)
                    Text(verbatim: profile.name).font(.headline)
                    Spacer()
                    Button("Remove") { settings.appProfiles[id] = nil }.buttonStyle(.link)
                }
                Picker("Text recognition", selection: binding(\.ocr)) {
                    Text(settings.vision ? "Same as General (On)" : "Same as General (Off)").tag(AppOverride.inherit)
                    Text("On").tag(AppOverride.on)
                    Text("Off").tag(AppOverride.off)
                }
                if behavior.ocr {
                    Picker("Prepare text labels in advance", selection: binding(\.prescan)) {
                        Text(settings.prescanText ? "Same as General (On)" : "Same as General (Off)").tag(AppOverride.inherit)
                        Text("On").tag(AppOverride.on)
                        Text("Off").tag(AppOverride.off)
                    }
                }
                Picker("Scan time", selection: binding(\.scanTime)) {
                    Text("Normal").tag(ScanTime.normal)
                    Text("Extended").tag(ScanTime.extended)
                }
                if AppAnalyzer.kind(of: id).enhanceable || profile.enhanced {
                    Toggle("Enhanced accessibility", isOn: binding(\.enhanced))
                    Text(AppAdvice.enhance.risk).font(.caption).foregroundStyle(.secondary)
                }
            }.padding(8).frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    private func section<Content: View>(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            GroupBox { VStack(alignment: .leading, spacing: 10) { content() }.padding(8).frame(maxWidth: .infinity, alignment: .leading) }
        }
    }
    private func colorPicker(_ role: AppearanceColor) -> some View {
        ColorPicker(colorTitle(role), selection: Binding(get: { settings.color(role) }, set: { settings.setColor($0, for: role) }), supportsOpacity: false).font(.callout)
    }
    private func schemeTitle(_ scheme: LabelColorScheme) -> String {
        switch scheme.id {
        case "pastel": return String(localized: "Pastel")
        case "colorblind": return String(localized: "Color-blind safe")
        case "bold": return String(localized: "Bold")
        case "neon": return String(localized: "Neon")
        default: return String(localized: "Vivid")
        }
    }
    /// One selectable scheme: its name and a strip of its eight colors.
    private func schemeRow(_ scheme: LabelColorScheme) -> some View {
        let selected = settings.colorScheme == scheme
        return Button { settings.colorScheme = scheme } label: {
            HStack(spacing: 10) {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle").foregroundStyle(selected ? Color.accentColor : .secondary)
                Text(schemeTitle(scheme)).frame(width: 120, alignment: .leading)
                HStack(spacing: 3) {
                    ForEach(scheme.hexes, id: \.self) { hex in
                        RoundedRectangle(cornerRadius: 3).fill(Color(nsColor: Settings.color(hex: hex))).frame(width: 18, height: 14)
                    }
                }
                Spacer(minLength: 0)
            }.contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityAddTraits(selected ? .isSelected : [])
    }
    private func colorTitle(_ role: AppearanceColor) -> String {
        switch role {
        case .label: return String(localized: "Label tint")
        case .ocr: return String(localized: "OCR label tint")
        case .grid: return String(localized: "Grid lines")
        case .text: return String(localized: "Label text")
        case .highlight: return String(localized: "Match & selection")
        }
    }
    private func pointerTitle(_ placement: ScrollPointerPlacement) -> String {
        switch placement {
        case .rightEdge: return String(localized: "Right edge")
        case .leftEdge: return String(localized: "Left edge")
        case .bottomEdge: return String(localized: "Bottom edge")
        case .bottomRightCorner: return String(localized: "Bottom-right corner")
        case .center: return String(localized: "Center")
        case .stay: return String(localized: "Don’t move")
        }
    }
    private func positionTitle(_ position: HintPosition) -> String {
        switch position {
        case .leading: return String(localized: "Left of the element")
        case .trailing: return String(localized: "Right of the element")
        case .above: return String(localized: "Above the element")
        case .below: return String(localized: "Below the element")
        case .center: return String(localized: "On the element")
        }
    }
    private func languageName(_ code: String) -> String {
        Locale(identifier: AppLanguage.current).localizedString(forIdentifier: code) ?? code
    }
    private func setLanguage(_ code: String, selected: Bool) {
        var languages = settings.ocrLanguages
        if selected { if !languages.contains(code) { languages.append(code) } }
        else if languages.count > 1 { languages.removeAll { $0 == code } }  // keep at least one
        settings.ocrLanguages = languages
    }
    private func moveLanguage(_ index: Int, by step: Int) {
        var languages = settings.ocrLanguages
        let destination = index + step
        guard languages.indices.contains(destination) else { return }
        languages.swapAt(index, destination); settings.ocrLanguages = languages
    }
    /// Every selected language is read in the same scan, in this order.
    private var ocrLanguages: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Text recognition languages").font(.subheadline.weight(.semibold))
            ForEach(Array(settings.ocrLanguages.enumerated()), id: \.element) { index, code in
                HStack {
                    Toggle(isOn: Binding(get: { true }, set: { setLanguage(code, selected: $0) })) { Text(verbatim: languageName(code)) }
                        .toggleStyle(.checkbox).disabled(settings.ocrLanguages.count == 1)
                    Spacer()
                    Button { moveLanguage(index, by: -1) } label: { Image(systemName: "chevron.up") }
                        .buttonStyle(.borderless).disabled(index == 0).accessibilityLabel(Text("Move up"))
                    Button { moveLanguage(index, by: 1) } label: { Image(systemName: "chevron.down") }
                        .buttonStyle(.borderless).disabled(index == settings.ocrLanguages.count - 1).accessibilityLabel(Text("Move down"))
                }
            }
            DisclosureGroup("More languages") {
                ForEach(OCRProvider.supportedLanguages.filter { !settings.ocrLanguages.contains($0) }, id: \.self) { code in
                    Toggle(isOn: Binding(get: { false }, set: { setLanguage(code, selected: $0) })) { Text(verbatim: languageName(code)) }
                        .toggleStyle(.checkbox)
                }
            }
            Text("Text in every selected language is found in the same scan. Each additional writing system adds a recognition pass, so scans take slightly longer.").font(.caption).foregroundStyle(.secondary)
        }
    }
    private func permission(_ title: LocalizedStringKey, id: String, detail: LocalizedStringKey, granted: Bool, action: @escaping () -> Void) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: granted ? "checkmark.circle.fill" : "circle.dashed").foregroundStyle(granted ? .teal : .secondary).font(.title2)
            VStack(alignment: .leading, spacing: 5) { Text(title).font(.headline); Text(detail).font(.caption).foregroundStyle(.secondary) }
            Spacer()
            Button(granted ? "Granted" : "Enable", action: action).disabled(granted)
        }.padding(12).background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 12)).id("\(id)-\(permissionRevision)")
    }
}

struct ShortcutRecorder: NSViewRepresentable {
    @Binding var shortcut: Shortcut
    func makeNSView(context: Context) -> RecorderButton { let button = RecorderButton(); button.onChange = { shortcut = $0 }; return button }
    func updateNSView(_ view: RecorderButton, context: Context) { view.shortcut = shortcut; if !view.recording { view.title = shortcutTitle(shortcut) } }
}
final class RecorderButton: NSButton {
    var shortcut = Shortcut(0, [.command])
    var onChange: ((Shortcut) -> Void)?
    var recording = false
    override var acceptsFirstResponder: Bool { true }
    override init(frame: NSRect) { super.init(frame: frame); bezelStyle = .rounded; target = self; action = #selector(record) }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
    @objc private func record() { recording = true; title = String(localized: "Type shortcut…"); window?.makeFirstResponder(self) }
    override func keyDown(with event: NSEvent) {
        guard recording else { super.keyDown(with: event); return }
        if event.keyCode == 53 { recording = false; title = shortcutTitle(shortcut); return }
        let modifiers = KeyModifiers(event.cgEvent?.flags ?? [])
        guard !modifiers.intersection([.command, .control, .option]).isEmpty, physicalKeys[event.keyCode] != nil else { NSSound.beep(); return }
        shortcut = Shortcut(event.keyCode, modifiers); recording = false; title = shortcutTitle(shortcut); onChange?(shortcut)
    }
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if recording { keyDown(with: event); return true }; return super.performKeyEquivalent(with: event)
    }
}

extension AppAdvice {
    var title: String {
        switch self {
        case .enhance: return String(localized: "Turn on enhanced accessibility")
        case .ocr: return String(localized: "Turn on text recognition for this app")
        case .extendScan: return String(localized: "Use Extended scan time")
        }
    }
    var risk: String {
        switch self {
        case .enhance: return String(localized: "Asks the app for its full accessibility tree, and keeps one label per row. The app stays in this mode until Spray Can turns it off or quits; window managers may move its windows more slowly.")
        case .ocr: return String(localized: "Reads the window with on-device text recognition when you activate. Needs Screen Recording; text labels mark text, which may not be clickable.")
        case .extendScan: return String(localized: "Waits up to 2 s instead of 0.85 s for the app’s controls, so labels may appear later.")
        }
    }
}

extension AppKind {
    var title: String {
        switch self {
        case .native: return String(localized: "Native")
        case .electron: return "Electron"
        case .chromium: return "Chromium"
        case .cef: return "CEF"
        case .webView2: return "WebView2"
        case .qt: return "Qt"
        case .flutter: return "Flutter"
        }
    }
}

/// Analyze chosen apps (read-only), show a feasibility table with risks, and apply what the user ticks.
struct AppAnalysisSection: View {
    @ObservedObject var analyzer: AppAnalyzer
    @State private var chosen = Set<String>()
    @State private var accepted: [String: Set<AppAdvice>] = [:]
    @State private var confirming = false
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Analyze apps").font(.headline).padding(.top, 8)
            Text("See how well Spray Can reads each app and what would help. Analysis only reads; nothing changes until you apply a suggestion. Each app needs an open window.").font(.caption).foregroundStyle(.secondary)
            GroupBox {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(AppProfileCandidates.running(excluding: []), id: \.id) { app in
                        Toggle(isOn: Binding(get: { chosen.contains(app.id) }, set: { if $0 { chosen.insert(app.id) } else { chosen.remove(app.id) } })) {
                            HStack(spacing: 6) { Image(nsImage: AppProfileCandidates.icon(for: app.id)).resizable().frame(width: 16, height: 16); Text(verbatim: app.name) }
                        }.toggleStyle(.checkbox)
                    }
                }.padding(6).frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack {
                Button("Analyze Selected") { analyzer.analyze(chosen.sorted()) }.disabled(chosen.isEmpty || analyzer.busy)
                if analyzer.busy { ProgressView().controlSize(.small) }
            }
            ForEach(analyzer.entries.keys.sorted { (analyzer.entries[$0]?.name ?? $0).localizedCaseInsensitiveCompare(analyzer.entries[$1]?.name ?? $1) == .orderedAscending }, id: \.self) { id in
                if let entry = analyzer.entries[id] { result(id, entry) }
            }
            if accepted.values.contains(where: { !$0.isEmpty }) {
                Button("Apply Selected Suggestions…") { confirming = true }.disabled(analyzer.busy)
                    .alert("Apply these suggestions?", isPresented: $confirming) {
                        Button("Apply") {
                            for (id, advice) in accepted where !advice.isEmpty { analyzer.apply(id, advice) }
                            accepted = [:]
                        }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text(confirmation)
                    }
            }
        }
    }
    private var confirmation: String {
        accepted.filter { !$0.value.isEmpty }.sorted { $0.key < $1.key }.map { id, advice in
            (analyzer.entries[id]?.name ?? id) + ": " + advice.sorted { $0.rawValue < $1.rawValue }.map(\.title).joined(separator: ", ")
        }.joined(separator: "\n") + "\n\n" + String(localized: "Enhanced accessibility is tried first and turned off again if it doesn’t help. You can change or remove every app setting above.")
    }
    private func result(_ id: String, _ entry: AppAnalyzer.Entry) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Image(nsImage: AppProfileCandidates.icon(for: id)).resizable().frame(width: 22, height: 22)
                    Text(verbatim: entry.name).font(.headline)
                    if let kind = entry.analysis?.kind { Text(verbatim: kind.title).font(.caption).padding(.horizontal, 6).padding(.vertical, 2).background(.quaternary, in: Capsule()) }
                    Spacer()
                }
                if let problem = entry.problem { Text(problem).font(.callout).foregroundStyle(.secondary) }
                if let analysis = entry.analysis {
                    Text("Labels \(analysis.labels) · Text covered \(AppAnalyzer.percent(analysis.coverage)) · Scan \(analysis.scanMilliseconds) ms").font(.callout).monospacedDigit()
                    if entry.advice.isEmpty && entry.outcome == nil { Text("Reads well. No changes needed.").font(.callout).foregroundStyle(.secondary) }
                    ForEach(entry.advice, id: \.self) { advice in
                        Toggle(isOn: Binding(get: { accepted[id, default: []].contains(advice) },
                                             set: { if $0 { accepted[id, default: []].insert(advice) } else { accepted[id]?.remove(advice) } })) {
                            VStack(alignment: .leading, spacing: 2) { Text(advice.title); Text(advice.risk).font(.caption).foregroundStyle(.secondary) }
                        }.toggleStyle(.checkbox)
                    }
                }
                if let outcome = entry.outcome { Text(outcome).font(.callout).foregroundStyle(.teal) }
            }.padding(6).frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
