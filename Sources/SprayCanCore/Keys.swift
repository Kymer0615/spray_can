import Foundation
import CoreGraphics

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
    /// ⌘ and ⌃ shortcuts Spray Can has no binding for (copy, paste, close window, Spotlight,
    /// input-source switching) go to macOS and the app during navigation. Plain, Shift, and ⌥ keys
    /// never pass, so labels and movement keys can't type into the app.
    public static func passesThrough(code: UInt16, text: String, modifiers: KeyModifiers, vi: Bool) -> Bool {
        guard !modifiers.isDisjoint(with: [.command, .control]) else { return false }
        return action(code: code, text: text, modifiers: modifiers, vi: vi) == .none
    }
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
        // Space presses and holds the button, then drops it, keeping the same labels.
        if code == 49 && m.isEmpty { return .hold }
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

/// Wheel values for a scroll where positive `y` reveals content below and positive `x` content to the right.
/// macOS applies the natural-scrolling setting to synthesized wheel events as well (it flips their sign in
/// transit), so the posted sign must follow that setting for keys to scroll the way they say.
public enum ScrollDirection {
    public static func wheelDeltas(x: Int, y: Int, natural: Bool) -> (vertical: Int32, horizontal: Int32) {
        natural ? (Int32(clamping: y), Int32(clamping: x)) : (Int32(clamping: -y), Int32(clamping: -x))
    }
}

/// Eased scrolling: each tick sends a fraction of what is left, so motion starts quickly and settles
/// smoothly. Whole-pixel steps; the fraction is carried, so the total arrives exactly.
public enum ScrollAnimation {
    public static let fraction = 0.18
    /// The share of the remaining distance sent per 120 Hz tick for a 0…1 smoothness setting,
    /// or nil for 0 (instant). 0.75, the default, gives 0.18 (about 150 ms per step); 1 gives 0.07.
    public static func fraction(smoothness: Double) -> Double? {
        guard smoothness > 0.001 else { return nil }
        let level = min(1, max(0, smoothness))
        // Piecewise linear: 0.5 → 0.18 up to the default, then 0.18 → 0.07.
        return level <= 0.75 ? 0.5 - (0.5 - 0.18) * level / 0.75 : 0.18 - (0.18 - 0.07) * (level - 0.75) / 0.25
    }
    /// The pixels to send this tick and what remains afterwards.
    public static func next(remaining: Double, fraction: Double = ScrollAnimation.fraction) -> (step: Int, remaining: Double) {
        guard abs(remaining) >= 1 else { return (0, remaining) }
        let wanted = remaining * fraction
        // At least one pixel per tick, never past the target.
        let magnitude = min(abs(remaining).rounded(.down), max(1, abs(wanted).rounded()))
        let step = Int(remaining < 0 ? -magnitude : magnitude)
        return (step, remaining - Double(step))
    }
}

/// Where scroll mode keeps the pointer. Scroll events go to the pointer, so it must be inside the area.
public enum ScrollPointerPlacement: String, CaseIterable {
    case rightEdge, leftEdge, bottomEdge, bottomRightCorner, center, stay
    /// The pointer position inside `frame` (top-left-origin coordinates), or nil to leave it where it is.
    public func point(in frame: CGRect) -> CGPoint? {
        let dx = min(12, frame.width / 2), dy = min(12, frame.height / 2)
        switch self {
        case .rightEdge: return CGPoint(x: frame.maxX - dx, y: frame.midY)
        case .leftEdge: return CGPoint(x: frame.minX + dx, y: frame.midY)
        case .bottomEdge: return CGPoint(x: frame.midX, y: frame.maxY - dy)
        case .bottomRightCorner: return CGPoint(x: frame.maxX - min(16, frame.width / 2), y: frame.maxY - min(16, frame.height / 2))
        case .center: return CGPoint(x: frame.midX, y: frame.midY)
        case .stay: return nil
        }
    }
}

/// After a Return click, a second unmodified Return within the double-click interval turns it into
/// a double-click. Anything else, or a late press, goes to the app as usual.
public enum DoubleClickWindow {
    public static func accepts(code: UInt16, modifiers: KeyModifiers, elapsed: TimeInterval, interval: TimeInterval) -> Bool {
        (code == 36 || code == 76) && modifiers.isEmpty && elapsed >= 0 && elapsed <= interval
    }
}

/// Return clicks on release; held past the threshold it right-clicks instead.
public enum ReturnPress {
    public static let threshold: TimeInterval = 0.45
    /// The button for a Return held this long: 0 = left, 1 = right.
    public static func button(heldFor duration: TimeInterval, threshold: TimeInterval = ReturnPress.threshold) -> Int {
        duration >= threshold ? 1 : 0
    }
    /// Whether an unmodified Return should wait to see if it becomes a long press.
    public static func defers(code: UInt16, modifiers: KeyModifiers, holding: Bool, enabled: Bool) -> Bool {
        enabled && !holding && modifiers.isEmpty && (code == 36 || code == 76)
    }
}

/// Keys that belong to scroll mode. Any other key ends scroll mode and goes to the app,
/// except ⌘/⌃ shortcuts, which are either Spray Can's own or pass through without ending it.
public enum ScrollKeys {
    public static func keeps(code: UInt16, text: String, modifiers: KeyModifiers) -> Bool {
        if code == 53 { return true }                                   // Esc exits through the session
        if text == "[" && modifiers == .control { return true }         // ⌃[ exits too
        guard modifiers.isEmpty || modifiers == .shift else { return false }
        if code == 48 { return true }                                   // Tab / ⇧Tab switch areas
        if (123...126).contains(code) { return true }                   // arrows scroll
        return ["h", "j", "k", "l", "d", "u", "g"].contains(text.lowercased())
    }
    /// Arrow keys as their HJKL equivalents.
    public static func letter(forArrow code: UInt16) -> String? {
        [123: "h", 124: "l", 125: "j", 126: "k"][code]
    }
}
