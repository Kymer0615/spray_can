import AppKit
import SwiftUI
import SprayCanCore

final class Settings: ObservableObject {
    static let shared = Settings()
    @Published var glassEnabled = Settings.flag("glassEnabled", true) { didSet { save("glassEnabled", glassEnabled) } }
    @Published var vision = UserDefaults.standard.bool(forKey: "vision") { didSet { save("vision", vision) } }
    @Published var allWindows = UserDefaults.standard.bool(forKey: "allWindows") { didSet { save("allWindows", allWindows) } }
    @Published var instantClick = UserDefaults.standard.bool(forKey: "instantClick") { didSet { save("instantClick", instantClick) } }
    @Published var vi = UserDefaults.standard.bool(forKey: "vi") { didSet { save("vi", vi) } }
    @Published var cellSize = Settings.number("cellSize", 100) { didSet { save("cellSize", cellSize) } }
    @Published var fontSize = Settings.number("fontSize", 13) { didSet { save("fontSize", fontSize) } }
    @Published var contrast = Settings.number("contrast", 0.85) { didSet { save("contrast", contrast) } }
    /// Ordered Vision language codes; every selected script is recognized in the same scan.
    @Published var ocrLanguages: [String] = OCRLanguages.normalized(
        UserDefaults.standard.stringArray(forKey: "ocrLanguages")
            ?? OCRLanguages.defaultSelection(preferred: Locale.preferredLanguages, supported: OCRProvider.supportedLanguages),
        supported: OCRProvider.supportedLanguages
    ) { didSet { save("ocrLanguages", ocrLanguages) } }
    /// Interface language chosen in Settings; nil follows macOS. Applies after relaunch.
    @Published var appLanguage: String? = AppLanguage.saved { didSet { AppLanguage.save(appLanguage) } }
    /// The choice in effect for this launch; a different selection needs a relaunch.
    let launchLanguage = AppLanguage.saved
    /// Labels sit beside their element by default so they never hide it.
    @Published var hintPosition = HintPosition(rawValue: UserDefaults.standard.string(forKey: "hintPosition") ?? "") ?? .leading {
        didSet { save("hintPosition", hintPosition.rawValue) }
    }
    @Published var hintOffsetX = Settings.number("hintOffsetX", 0) { didSet { save("hintOffsetX", hintOffsetX) } }
    @Published var hintOffsetY = Settings.number("hintOffsetY", 0) { didSet { save("hintOffsetY", hintOffsetY) } }
    /// Overlay views use bottom-left-origin coordinates.
    var hintStyle: HintPlacementStyle {
        HintPlacementStyle(position: hintPosition, offset: CGSize(width: hintOffsetX, height: hintOffsetY), yAxisUp: true)
    }
    func restoreHintPlacement() { hintPosition = .leading; hintOffsetX = 0; hintOffsetY = 0 }
    /// Let ⌘ and ⌃ shortcuts Spray Can doesn't use reach macOS and apps during navigation.
    @Published var passSystemShortcuts = Settings.flag("passSystemShortcuts", true) { didSet { save("passSystemShortcuts", passSystemShortcuts) } }
    /// Skip OCR text that an element label already covers.
    @Published var dedupeOCR = Settings.flag("dedupeOCR", true) { didSet { save("dedupeOCR", dedupeOCR) } }
    /// Draw each element label, its connector, and a box around its element in a shared color.
    @Published var colorCodeTargets = Settings.flag("colorCodeTargets", true) { didSet { save("colorCodeTargets", colorCodeTargets) } }
    /// When elements are shaded in their label's color, and how strongly.
    @Published var elementShading = ElementShading(rawValue: UserDefaults.standard.string(forKey: "elementShading") ?? "") ?? .always {
        didSet { save("elementShading", elementShading.rawValue) }
    }
    @Published var shadingOpacity = Settings.number("shadingOpacity", 0.16) { didSet { save("shadingOpacity", shadingOpacity) } }
    func restoreShading() { elementShading = .always; shadingOpacity = 0.16; colorScheme = .vivid }
    /// The color scheme used for color-coded labels.
    @Published var colorScheme = LabelColorScheme.named(UserDefaults.standard.string(forKey: "colorScheme")) { didSet { save("colorScheme", colorScheme.id) } }
    var palette: [NSColor] { colorScheme.hexes.map(Settings.color(hex:)) }
    static func color(hex: String) -> NSColor {
        let rgb = UInt32(hex, radix: 16) ?? 0
        let red = Double((rgb >> 16) & 255) / 255, green = Double((rgb >> 8) & 255) / 255, blue = Double(rgb & 255) / 255
        return NSColor(srgbRed: red, green: green, blue: blue, alpha: 1)
    }
    /// Black or white label text, whichever reads better on a color-coded badge.
    static func textColor(on color: NSColor) -> NSColor {
        guard let rgb = color.usingColorSpace(.sRGB) else { return .white }
        let red: CGFloat = 0.2126 * rgb.redComponent, green: CGFloat = 0.7152 * rgb.greenComponent, blue: CGFloat = 0.0722 * rgb.blueComponent
        let luminance: CGFloat = red + green + blue
        return luminance > 0.55 ? NSColor(white: 0.08, alpha: 1) : .white
    }
    @Published var showLines = true
    @Published var showLabels = true
    @Published var shortcuts: [NavigationMode: Shortcut] = {
        guard let data = UserDefaults.standard.data(forKey: "shortcuts"),
              let value = try? JSONDecoder().decode([NavigationMode: Shortcut].self, from: data) else { return Shortcut.defaults }
        return Shortcut.defaults.merging(value) { _, new in new }
    }() { didSet { if let data = try? JSONEncoder().encode(shortcuts) { save("shortcuts", data) } } }
    @Published var colors: [String: String] = UserDefaults.standard.dictionary(forKey: "appearanceColors") as? [String: String] ?? [:] {
        didSet { save("appearanceColors", colors) }
    }
    func color(_ role: AppearanceColor) -> Color { Color(nsColor: nsColor(role)) }
    func nsColor(_ role: AppearanceColor) -> NSColor {
        let hex = role.validated(colors[role.rawValue])
        let rgb = UInt32(hex, radix: 16)!
        let red = Double((rgb >> 16) & 255) / 255, green = Double((rgb >> 8) & 255) / 255, blue = Double(rgb & 255) / 255
        return NSColor(srgbRed: red, green: green, blue: blue, alpha: 1)
    }
    func setColor(_ color: Color, for role: AppearanceColor) {
        guard let rgb = NSColor(color).usingColorSpace(.sRGB) else { return }
        colors[role.rawValue] = String(format: "%02X%02X%02X", Int((rgb.redComponent * 255).rounded()), Int((rgb.greenComponent * 255).rounded()), Int((rgb.blueComponent * 255).rounded()))
    }
    func restoreColors() { colors = [:] }
    private func save(_ key: String, _ value: Any) { UserDefaults.standard.set(value, forKey: key) }
    /// Saved or command-line values. Command-line defaults (`-key NO`, `-key 0.3`) arrive as strings,
    /// which `bool(forKey:)` and `double(forKey:)` understand but a cast to Bool or Double does not.
    static func flag(_ key: String, _ fallback: Bool) -> Bool { UserDefaults.standard.object(forKey: key) == nil ? fallback : UserDefaults.standard.bool(forKey: key) }
    static func number(_ key: String, _ fallback: Double) -> Double { UserDefaults.standard.object(forKey: key) == nil ? fallback : UserDefaults.standard.double(forKey: key) }
}

enum ElementShading: String, CaseIterable {
    case off, whileTyping, always
    var title: String {
        switch self {
        case .off: return String(localized: "Off")
        case .whileTyping: return String(localized: "While typing")
        case .always: return String(localized: "Always")
        }
    }
}

/// Interface languages shipped in the app bundle, named in their own language.
enum AppLanguage {
    static let options: [(code: String, name: String)] = [
        ("en", "English"), ("zh-Hans", "简体中文"), ("zh-Hant", "繁體中文"), ("ja", "日本語"), ("ko", "한국어"), ("es", "Español")
    ]
    /// Only Spray Can's own domain is read or written, never the global language list.
    static var saved: String? {
        let domain = UserDefaults.standard.persistentDomain(forName: Bundle.main.bundleIdentifier ?? "") ?? [:]
        return (domain["AppleLanguages"] as? [String])?.first.flatMap { code in options.first { $0.code == code }?.code }
    }
    static func save(_ code: String?) {
        if let code { UserDefaults.standard.set([code], forKey: "AppleLanguages") }
        else { UserDefaults.standard.removeObject(forKey: "AppleLanguages") }
    }
    /// The localization macOS chose for this launch.
    static var current: String { Bundle.main.preferredLocalizations.first ?? "en" }
    static func relaunch() {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: configuration) { _, error in
            if error == nil { DispatchQueue.main.async { NSApp.terminate(nil) } }
        }
    }
}

extension NavigationMode {
    var localizedTitle: String {
        switch self {
        case .elements: return String(localized: "Elements")
        case .grid: return String(localized: "Grid")
        case .freestyle: return String(localized: "Freestyle")
        case .scroll: return String(localized: "Scroll")
        }
    }
}

extension KeyModifiers {
    init(_ flags: CGEventFlags) {
        var value: Self = []
        if flags.contains(.maskShift) { value.insert(.shift) }
        if flags.contains(.maskControl) { value.insert(.control) }
        if flags.contains(.maskAlternate) { value.insert(.option) }
        if flags.contains(.maskCommand) { value.insert(.command) }
        self = value
    }
    var cgFlags: CGEventFlags {
        var flags: CGEventFlags = []
        if contains(.shift) { flags.insert(.maskShift) }; if contains(.control) { flags.insert(.maskControl) }
        if contains(.option) { flags.insert(.maskAlternate) }; if contains(.command) { flags.insert(.maskCommand) }
        return flags
    }
    var symbols: String { (contains(.control) ? "⌃" : "") + (contains(.option) ? "⌥" : "") + (contains(.shift) ? "⇧" : "") + (contains(.command) ? "⌘" : "") }
}

let physicalKeys: [UInt16: String] = [0:"a",1:"s",2:"d",3:"f",4:"h",5:"g",6:"z",7:"x",8:"c",9:"v",11:"b",12:"q",13:"w",14:"e",15:"r",16:"y",17:"t",18:"1",19:"2",20:"3",21:"4",22:"6",23:"5",24:"=",25:"9",26:"7",27:"-",28:"8",29:"0",30:"]",31:"o",32:"u",33:"[",34:"i",35:"p",37:"l",38:"j",39:"'",40:"k",41:";",42:"\\",43:",",44:"/",45:"n",46:"m",47:"."]

func shortcutTitle(_ shortcut: Shortcut) -> String {
    shortcut.modifiers.symbols + (physicalKeys[shortcut.keyCode]?.uppercased() ?? String(localized: "Key \(shortcut.keyCode)"))
}
