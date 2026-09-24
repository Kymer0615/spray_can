import AppKit
import SwiftUI
import SprayCanCore

final class Settings: ObservableObject {
    static let shared = Settings()
    @Published var glassEnabled = UserDefaults.standard.object(forKey: "glassEnabled") as? Bool ?? true { didSet { save("glassEnabled", glassEnabled) } }
    @Published var vision = UserDefaults.standard.bool(forKey: "vision") { didSet { save("vision", vision) } }
    @Published var allWindows = UserDefaults.standard.bool(forKey: "allWindows") { didSet { save("allWindows", allWindows) } }
    @Published var instantClick = UserDefaults.standard.bool(forKey: "instantClick") { didSet { save("instantClick", instantClick) } }
    @Published var vi = UserDefaults.standard.bool(forKey: "vi") { didSet { save("vi", vi) } }
    @Published var cellSize = UserDefaults.standard.object(forKey: "cellSize") as? Double ?? 100 { didSet { save("cellSize", cellSize) } }
    @Published var fontSize = UserDefaults.standard.object(forKey: "fontSize") as? Double ?? 13 { didSet { save("fontSize", fontSize) } }
    @Published var contrast = UserDefaults.standard.object(forKey: "contrast") as? Double ?? 0.85 { didSet { save("contrast", contrast) } }
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
        return NSColor(srgbRed: Double((rgb >> 16) & 255) / 255, green: Double((rgb >> 8) & 255) / 255, blue: Double(rgb & 255) / 255, alpha: 1)
    }
    func setColor(_ color: Color, for role: AppearanceColor) {
        guard let rgb = NSColor(color).usingColorSpace(.sRGB) else { return }
        colors[role.rawValue] = String(format: "%02X%02X%02X", Int((rgb.redComponent * 255).rounded()), Int((rgb.greenComponent * 255).rounded()), Int((rgb.blueComponent * 255).rounded()))
    }
    func restoreColors() { colors = [:] }
    private func save(_ key: String, _ value: Any) { UserDefaults.standard.set(value, forKey: key) }
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
    shortcut.modifiers.symbols + (physicalKeys[shortcut.keyCode]?.uppercased() ?? "Key \(shortcut.keyCode)")
}
