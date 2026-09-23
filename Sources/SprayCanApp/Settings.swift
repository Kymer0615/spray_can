import AppKit
import SwiftUI
import SprayCanCore

final class Settings: ObservableObject {
    static let shared = Settings()
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
