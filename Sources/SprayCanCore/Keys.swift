import Foundation

public struct KeyModifiers: OptionSet, Equatable, Codable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
    public static let shift = Self(rawValue: 1)
    public static let control = Self(rawValue: 2)
    public static let option = Self(rawValue: 4)
    public static let command = Self(rawValue: 8)
}

/// Activation modifiers are ignored only until each originally held modifier is released.
public struct ActivationModifiers {
    private var inherited: KeyModifiers = []
    public init() {}
    public mutating func begin(_ modifiers: KeyModifiers) { inherited = modifiers }
    public mutating func observe(_ modifiers: KeyModifiers) { inherited.formIntersection(modifiers) }
    public func labelModifiers(_ modifiers: KeyModifiers) -> KeyModifiers { modifiers.subtracting(inherited) }
}

public struct Shortcut: Codable, Equatable {
    public var keyCode: UInt16
    public var modifiers: KeyModifiers
    public init(_ keyCode: UInt16, _ modifiers: KeyModifiers) { self.keyCode = keyCode; self.modifiers = modifiers }
    public static let defaults: [NavigationMode: Shortcut] = [
        .elements: Shortcut(38, [.shift, .command]), .grid: Shortcut(40, [.shift, .command]),
        .freestyle: Shortcut(37, [.shift, .command]), .scroll: Shortcut(38, [.control])]
}

public enum KeyAction: Equatable {
    case label(Character), escape, backspace, hide, settings
    case click(Int), doubleClick, hold, move(Int, Int, Bool), edge(Int, Int), center
    case scroll(Int, Int), toggleLines, toggleLabels, cellSize(Int), contrast(Int), none
}

public enum KeyMap {
    public static func action(code: UInt16, text: String, modifiers m: KeyModifiers, vi: Bool) -> KeyAction {
        let c = text.lowercased()
        if code == 53 || (c == "g" && m == .control) || (c == "." && m == .command) { return .escape }
        if c == "h" && m == .command { return .hide }
        if c == "," && m == .command { return .settings }
        if code == 51 { return .backspace }
        if c == "=" || c == "+" {
            if m == .control { return .toggleLines }
            if m == [.control, .shift] { return .toggleLabels }
            if m == [.command, .shift] { return .cellSize(1) }
            if m == .command { return .contrast(1) }
            return .hold
        }
        if c == "-" || c == "_" {
            if m == [.command, .shift] { return .cellSize(-1) }
            if m == .command { return .contrast(-1) }
        }
        if code == 36 || code == 76 { return .click(0) }
        if c == "[" { return .click(2) }; if c == "]" { return .click(1) }
        if c == "\\" { return .doubleClick }
        let arrows: [UInt16: (Int, Int)] = [123: (-1, 0), 124: (1, 0), 125: (0, 1), 126: (0, -1)]
        if let (x, y) = arrows[code] {
            if m == .shift { return .scroll(x, y) }
            if m == .command { return .edge(x, y) }
            return .move(x, y, m == .option)
        }
        if vi {
            let directions = ["h": (-1, 0), "l": (1, 0), "j": (0, 1), "k": (0, -1)]
            if let (x, y) = directions[c] {
                if m == .shift { return .edge(x, y) }
                if m.isEmpty || m == .control { return .move(x, y, m == .control) }
            }
            if c == "m" && m == .shift { return .center }
            if m == .control {
                if c == "b" { return .scroll(0, -1) }; if c == "f" { return .scroll(0, 1) }
                if c == "i" { return .scroll(-1, 0) }; if c == "a" { return .scroll(1, 0) }
            }
        } else {
            if m == .control {
                switch c {
                case "p": return .move(0, -1, false)
                case "n": return .move(0, 1, false)
                case "b": return .move(-1, 0, false)
                case "f": return .move(1, 0, false)
                case "a": return .edge(-1, 0)
                case "e": return .edge(1, 0)
                case "l": return .center
                default: break
                }
            }
            if m == .option {
                switch c {
                case "a": return .move(0, -1, true)
                case "e": return .move(0, 1, true)
                case "b": return .move(-1, 0, true)
                case "f": return .move(1, 0, true)
                default: break
                }
            }
            if m == [.option, .shift] {
                if text == "<" { return .edge(0, -1) }; if text == ">" { return .edge(0, 1) }
            }
            if m == .shift {
                if c == "p" { return .scroll(0, -1) }; if c == "n" { return .scroll(0, 1) }
                if c == "b" { return .scroll(-1, 0) }; if c == "f" { return .scroll(1, 0) }
            }
        }
        if m.isEmpty, c.count == 1, let character = c.first, character.isASCII, character.isLetter { return .label(character) }
        return .none
    }
}
