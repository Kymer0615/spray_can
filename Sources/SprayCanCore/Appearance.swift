import Foundation

/// Portable, opaque sRGB color storage shared by preferences and rendering.
public enum AppearanceColor: String, CaseIterable {
    case label, ocr, grid, text, highlight
    public var defaultHex: String {
        switch self {
        case .label: return "08424A"
        case .ocr: return "5856D6"
        case .grid: return "30B0C7"
        case .text: return "FFFFFF"
        case .highlight: return "66DFC4"
        }
    }
    public func validated(_ value: String?) -> String {
        guard let value, value.count == 6, value.unicodeScalars.allSatisfy({
            (48...57).contains($0.value) || (65...70).contains($0.value) || (97...102).contains($0.value)
        }) else { return defaultHex }
        return value.uppercased()
    }
}

/// A color in CIELAB, where Euclidean distance (ΔE) approximates perceived difference.
public struct LabColor: Equatable {
    public let l: Double, a: Double, b: Double
    public init(l: Double, a: Double, b: Double) { self.l = l; self.a = a; self.b = b }
    /// Converts a six-digit sRGB hex string (D65 white).
    public init(hex: String) {
        let rgb = UInt32(hex, radix: 16) ?? 0
        func linear(_ shift: UInt32) -> Double {
            let c = Double((rgb >> shift) & 255) / 255
            return c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        let r = linear(16), g = linear(8), bl = linear(0)
        let x = (0.4124 * r + 0.3576 * g + 0.1805 * bl) / 0.95047
        let y = 0.2126 * r + 0.7152 * g + 0.0722 * bl
        let z = (0.0193 * r + 0.1192 * g + 0.9505 * bl) / 1.08883
        func f(_ t: Double) -> Double { t > 0.008856 ? cbrt(t) : 7.787 * t + 16 / 116 }
        l = 116 * f(y) - 16; a = 500 * (f(x) - f(y)); b = 200 * (f(y) - f(z))
    }
    public func distance(to other: LabColor) -> Double { ((l - other.l) * (l - other.l) + (a - other.a) * (a - other.a) + (b - other.b) * (b - other.b)).squareRoot() }
    /// Label colors: red, orange, yellow, green, cyan, blue, purple, pink.
    public static let labelPalette = ["E5484D", "F76B15", "FFC53D", "30A46C", "05A2C2", "0090FF", "8E4EC6", "D6409F"]
}

/// A named set of label colors for color coding. Colors are chosen for large CIELAB distances,
/// so neighboring labels stay distinct.
public struct LabelColorScheme: Equatable, Identifiable {
    public let id: String
    public let hexes: [String]
    public var lab: [LabColor] { hexes.map(LabColor.init(hex:)) }
    public static let vivid = LabelColorScheme(id: "vivid", hexes: LabColor.labelPalette)
    /// Soft fills with dark text; gentler on busy screens.
    public static let pastel = LabelColorScheme(id: "pastel", hexes: ["F4A7B9", "9FE2E0", "FBE7A1", "B9C3F7", "C7DDB5", "FFC8A2", "A9D6F5", "E0BBE4"])
    /// Okabe–Ito based: distinguishable with red–green color blindness.
    public static let colorBlindSafe = LabelColorScheme(id: "colorblind", hexes: ["E69F00", "0072B2", "009E73", "882255", "1A1A1A", "999999", "DDCC77", "D55E00"])
    /// Deep, saturated colors with white text; stands out on light windows.
    public static let bold = LabelColorScheme(id: "bold", hexes: ["B3123B", "1B7340", "303F9F", "6D4C41", "A84300", "5D6B00", "6A1B9A", "37474F"])
    /// Bright colors that stand out on dark windows.
    public static let neon = LabelColorScheme(id: "neon", hexes: ["B6FF3B", "A66BFF", "FF4545", "22E5FF", "FFC23B", "2BFF88", "FF3DD8", "3BFFD1"])
    public static let all = [vivid, pastel, colorBlindSafe, bold, neon]
    public static func named(_ id: String?) -> LabelColorScheme { all.first { $0.id == id } ?? .vivid }
}
