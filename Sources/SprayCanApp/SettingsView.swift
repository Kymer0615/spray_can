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
                ForEach(["General", "Shortcuts", "Appearance", "Permissions", "About"], id: \.self) { item in
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
    }
    private func icon(_ name: String) -> String {
        ["General":"cursorarrow.motionlines", "Shortcuts":"keyboard", "Appearance":"paintpalette", "Permissions":"hand.raised", "About":"info.circle"][name] ?? "circle"
    }
    @ViewBuilder private var content: some View {
        switch tab {
        case "General":
            Text("Reach your Mac without reaching for the mouse.").foregroundStyle(.secondary)
            GroupBox {
                VStack(alignment: .leading, spacing: 16) {
                    Toggle("Click as soon as a label is complete", isOn: $settings.instantClick)
                    Text("By default, labels move the pointer. Return clicks.").font(.caption).foregroundStyle(.secondary)
                    Toggle("Include all visible windows", isOn: $settings.allWindows)
                    Toggle("Use on-device text recognition", isOn: $settings.vision)
                    Text("Find text that apps don’t expose to accessibility. OCR labels mark text locations, which may not be clickable. Requires Screen Recording. Images stay in memory on this Mac.").font(.caption).foregroundStyle(.secondary)
                    Toggle("Hide text labels on known elements", isOn: $settings.dedupeOCR).disabled(!settings.vision)
                    Text("Skip recognized text that an element label already marks, such as a button’s title.").font(.caption).foregroundStyle(.secondary)
                    ocrLanguages.disabled(!settings.vision)
                    Toggle("Launch at login", isOn: $loginEnabled).onChange(of: loginEnabled) { _, value in
                        do { if value { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }; loginError = "" }
                        catch { loginError = error.localizedDescription }
                    }
                    if !loginError.isEmpty { Text(loginError).font(.caption).foregroundStyle(.red) }
                }.padding(10)
            }
            GroupBox {
                VStack(alignment: .leading, spacing: 10) {
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
                }.padding(10)
            }
            VStack(alignment: .leading, spacing: 10) {
                Text("A familiar flow").font(.headline)
                Text("⇧⌘J   Show element labels\nType a label   Move the pointer\nReturn   Click\nEsc   Clear a prefix, then exit").font(.system(.body, design: .monospaced)).lineSpacing(8)
            }
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
