import Foundation
import CoreGraphics

public enum NavigationMode: String, CaseIterable, Codable {
    case elements, grid, freestyle, scroll
    public var title: String { rawValue.capitalized }
}

public enum TargetSource: String, Codable { case accessibility, text, grid }

public struct Target: Identifiable, Equatable {
    public let id: String
    public var frame: CGRect
    public var source: TargetSource
    public var title: String
    public var role: String
    public var label: String
    public var point: CGPoint { CGPoint(x: frame.midX, y: frame.midY) }
    public init(id: String, frame: CGRect, source: TargetSource, title: String = "", role: String = "", label: String = "") {
        self.id = id; self.frame = frame; self.source = source
        self.title = title; self.role = role; self.label = label
    }
}

/// Hash collisions must never become identity collisions. Equality determines reuse.
public struct DiscoveryIdentity<Key: Hashable> {
    private var ids: [Key: String] = [:]
    private let namespace: String
    public init(namespace: String) { self.namespace = namespace }
    public mutating func id(for key: Key) -> String {
        if let id = ids[key] { return id }
        let id = "\(namespace)-\(ids.count)"
        ids[key] = id
        return id
    }
}
public enum TargetCollection {
    public static func unique(_ targets: [Target]) -> [Target] {
        var seen = Set<String>()
        return targets.filter { seen.insert($0.id).inserted && $0.frame.minX.isFinite && $0.frame.minY.isFinite && $0.frame.width.isFinite && $0.frame.height.isFinite }
    }
    /// Drops a target that is visually the same control as a smaller one inside it
    /// (a wrapper whose area is at most a quarter larger), keeping the innermost.
    public static func collapsed(_ targets: [Target]) -> [Target] {
        let bySize = unique(targets).sorted { ($0.frame.width * $0.frame.height, $0.id) < ($1.frame.width * $1.frame.height, $1.id) }
        var kept: [Target] = []
        for target in bySize {
            let area = target.frame.width * target.frame.height
            let wraps = kept.contains { inner in
                target.frame.insetBy(dx: -2, dy: -2).contains(inner.frame) && inner.frame.width * inner.frame.height * 1.25 >= area
            }
            if !wraps { kept.append(target) }
        }
        // A row that only wraps one titled control (a sidebar item's button) is that control.
        // A row holding only an untitled helper, such as a disclosure triangle, keeps its own label.
        let rows = kept.filter { $0.role == "AXRow" }
        let redundant = Set(rows.filter { row in
            let inside = kept.filter { $0.id != row.id && row.frame.insetBy(dx: -2, dy: -2).contains($0.frame) }
            return inside.count == 1 && !inside[0].title.isEmpty
        }.map(\.id))
        let ids = Set(kept.map(\.id)).subtracting(redundant)
        return targets.filter { ids.contains($0.id) }
    }
    public static func ordered(_ targets: [Target]) -> [Target] {
        unique(targets).sorted {
            if $0.frame.minY != $1.frame.minY { return $0.frame.minY < $1.frame.minY }
            if $0.frame.minX != $1.frame.minX { return $0.frame.minX < $1.frame.minX }
            return $0.id < $1.id
        }
    }
}

/// Coordinates in the core are always global Quartz points (top-left origin).
public enum Geometry {
    public static func cocoa(_ rect: CGRect, primaryHeight: CGFloat) -> CGRect {
        CGRect(x: rect.minX, y: primaryHeight - rect.maxY, width: rect.width, height: rect.height)
    }
    public static func grid(screens: [CGRect], cellSize: CGFloat) -> [Target] {
        screens.enumerated().flatMap { display, screen in
            let columns = max(1, Int(ceil(screen.width / max(24, cellSize))))
            let rows = max(1, Int(ceil(screen.height / max(24, cellSize))))
            return (0..<rows).flatMap { row in (0..<columns).map { col in
                Target(id: "grid-\(display)-\(row)-\(col)", frame: CGRect(
                    x: screen.minX + CGFloat(col) * screen.width / CGFloat(columns),
                    y: screen.minY + CGFloat(row) * screen.height / CGFloat(rows),
                    width: screen.width / CGFloat(columns), height: screen.height / CGFloat(rows)), source: .grid)
            }}
        }
    }
    public static func merge(_ existing: [Target], _ added: [Target]) -> [Target] {
        var result = existing
        for target in added where target.frame.width > 1 && target.frame.height > 1 {
            let duplicate = result.contains { other in
                if target.id == other.id { return true }
                let area = target.frame.intersection(other.frame)
                guard !area.isNull else { return false }
                let small = min(target.frame.width * target.frame.height, other.frame.width * other.frame.height)
                return area.width * area.height / max(1, small) > 0.65
            }
            if !duplicate { result.append(target) }
        }
        return result
    }
    /// OCR text is dropped where an accessibility target already labels it: text mostly inside
    /// an element, centered on an element not much larger than the text, or next to an element
    /// with the same title. A large element does not claim text that merely reaches into it.
    public static func mergeText(_ elements: [Target], _ text: [Target]) -> [Target] {
        func normalized(_ string: String) -> String { string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        let unknown = text.filter { candidate in
            let area = max(1, candidate.frame.width * candidate.frame.height)
            let center = CGPoint(x: candidate.frame.midX, y: candidate.frame.midY)
            let words = normalized(candidate.title)
            return !elements.contains { element in
                let frame = element.frame
                if frame.insetBy(dx: -4, dy: -4).contains(center) && frame.width * frame.height <= area * 8 { return true }
                guard !words.isEmpty, normalized(element.title) == words else { return false }
                let reach = max(candidate.frame.height, 8)
                return frame.insetBy(dx: -reach, dy: -reach).intersects(candidate.frame)
            }
        }
        return merge(elements, unknown)
    }
}

public enum HintLabels {
    public static func assign(_ targets: [Target], vi: Bool = false) -> [Target] {
        let targets = TargetCollection.unique(targets)
        let keys = Array(vi ? "asdfgqwertyuiopzxcvbnm" : "asdfjklghqweruioptyzxcvbnm")
        var length = 1, capacity = keys.count
        while capacity < targets.count { length += 1; capacity *= keys.count }
        return targets.enumerated().map { index, target in
            var n = index, letters = Array(repeating: keys[0], count: length)
            for position in (0..<length).reversed() { letters[position] = keys[n % keys.count]; n /= keys.count }
            var result = target; result.label = String(letters); return result
        }
    }
}

/// Generation-scoped state machine; all methods are called by the session's serial executor.
public struct NavigationSession {
    public enum Phase: Equatable { case idle, discovering, ready }
    public enum Outcome: Equatable { case ignored, buffered, filtered, invalid, selected(Target), cancelled }
    public private(set) var generation = 0
    public private(set) var phase: Phase = .idle
    public private(set) var mode: NavigationMode = .elements
    public private(set) var targets: [Target] = []
    public private(set) var prefix = ""
    public private(set) var hasTyped = false
    private var buffered: [Character] = []
    public init() {}
    @discardableResult public mutating func begin(_ mode: NavigationMode) -> Int {
        generation += 1; self.mode = mode; phase = .discovering
        targets = []; prefix = ""; buffered = []; hasTyped = false
        return generation
    }
    public mutating func publish(_ targets: [Target], generation: Int, vi: Bool = false) -> [Outcome] {
        guard generation == self.generation, phase != .idle else { return [] }
        // Once a user types, late providers may not reassign a label.
        guard phase == .discovering || !hasTyped else { return [] }
        self.targets = HintLabels.assign(targets, vi: vi); phase = .ready
        let pending = buffered; buffered = []
        return pending.map { type($0) }
    }
    public mutating func type(_ character: Character) -> Outcome {
        guard phase != .idle else { return .ignored }
        hasTyped = true
        if phase == .discovering {
            guard buffered.count < 32 else { return .invalid }
            buffered.append(character); return .buffered
        }
        let next = prefix + String(character).lowercased()
        let matches = targets.filter { $0.label.hasPrefix(next) }
        guard !matches.isEmpty else { return .invalid }
        if let exact = matches.first(where: { $0.label == next }) { prefix = ""; return .selected(exact) }
        prefix = next; return .filtered
    }
    public mutating func backspace() { if !buffered.isEmpty { buffered.removeLast() }; if !prefix.isEmpty { prefix.removeLast() } }
    public mutating func escape() -> Outcome {
        if !prefix.isEmpty || !buffered.isEmpty { prefix = ""; buffered = []; return .filtered }
        cancel(); return .cancelled
    }
    public mutating func cancel() {
        generation += 1; phase = .idle; targets = []; prefix = ""; buffered = []; hasTyped = false
    }
    public var visibleTargets: [Target] { targets.filter { $0.label.hasPrefix(prefix) } }
}
