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
