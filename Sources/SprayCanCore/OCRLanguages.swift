import Foundation
import CoreGraphics

/// Text recognized by one OCR pass, in global Quartz points.
public struct OCRText: Equatable {
    public var frame: CGRect
    public var text: String
    public var confidence: Float
    public init(frame: CGRect, text: String, confidence: Float) {
        self.frame = frame; self.text = text; self.confidence = confidence
    }
}

/// Vision reads several languages in one request only when they share a script
/// family; mixing e.g. Chinese, Japanese, and Korean lets the first dominate.
/// Languages are therefore grouped into passes that run on the same capture.
public enum OCRLanguages {
    public static let fallback = "en-US"
    /// Latin- and Cyrillic-script languages that Vision reads well together.
    static let combinable: Set<String> = ["en", "fr", "it", "de", "es", "pt", "ru", "uk", "tr", "id", "cs", "da", "nl", "no", "nn", "nb", "ms", "pl", "ro", "sv"]

    static func base(_ code: String) -> String {
        String(code.split(separator: "-").first ?? Substring(code)).lowercased()
    }

    /// Supported codes in the user's order, without duplicates; never empty.
    public static func normalized(_ selected: [String], supported: [String]) -> [String] {
        var seen = Set<String>()
        let valid = selected.filter { supported.contains($0) && seen.insert($0).inserted }
        return valid.isEmpty ? [supported.contains(fallback) ? fallback : supported.first ?? fallback] : valid
    }

    /// One request per pass. Combinable languages share the first pass; every
    /// other script gets its own, with English appended for mixed interface text.
    public static func passes(selected: [String], supported: [String]) -> [[String]] {
        let languages = normalized(selected, supported: supported)
        let shared = languages.filter { combinable.contains(base($0)) }
        var result: [[String]] = shared.isEmpty ? [] : [shared]
        for language in languages where !combinable.contains(base(language)) {
            let english = supported.contains(fallback) ? [fallback] : []
            result.append([language] + english)
        }
        // Keep the user's first choice first.
        if let first = languages.first, !combinable.contains(base(first)), !shared.isEmpty {
            result.append(result.removeFirst())
        }
        return result
    }

    /// Supported matches for the Mac's preferred languages, plus English.
    public static func defaultSelection(preferred: [String], supported: [String]) -> [String] {
        var result: [String] = []
        for language in preferred {
            let parts = language.split(separator: "-").map(String.init)
            let lang = parts.first?.lowercased() ?? ""
            let script = parts.dropFirst().first { $0.count == 4 }
            let candidates = supported.filter { base($0) == lang }
            // Prefer an exact match, then the same script (zh-Hans), then the language.
            let match = candidates.first { $0.caseInsensitiveCompare(language) == .orderedSame }
                ?? candidates.first { code in script.map { code.lowercased().contains($0.lowercased()) } ?? false }
                ?? (lang == "zh" ? nil : candidates.first)
            if let match, !result.contains(match) { result.append(match) }
        }
        if supported.contains(fallback) && !result.contains(fallback) { result.append(fallback) }
        return normalized(result, supported: supported)
    }

    /// Combines passes: overlapping results keep the most confident reading.
    public static func merge(_ passes: [[OCRText]], overlap: CGFloat = 0.65) -> [OCRText] {
        let all: [OCRText] = passes.flatMap { $0 }.filter { $0.frame.width > 0 && $0.frame.height > 0 }
        // Stable: equal confidence keeps pass order.
        let indexed: [(offset: Int, element: OCRText)] = Array(all.enumerated())
        let candidates: [OCRText] = indexed.sorted { lhs, rhs in
            if lhs.element.confidence != rhs.element.confidence { return lhs.element.confidence > rhs.element.confidence }
            return lhs.offset < rhs.offset
        }.map { $0.element }
        var kept: [OCRText] = []
        for candidate in candidates {
            let duplicate = kept.contains { other in
                let area = candidate.frame.intersection(other.frame)
                guard !area.isNull else { return false }
                let small = min(candidate.frame.width * candidate.frame.height, other.frame.width * other.frame.height)
                return area.width * area.height / max(1, small) > overlap
            }
            if !duplicate { kept.append(candidate) }
        }
        return kept
    }
}
