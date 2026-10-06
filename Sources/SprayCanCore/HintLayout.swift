import Foundation
import CoreGraphics

public struct HintLayoutItem: Equatable {
    public let id: String
    public let target: CGRect
    public let size: CGSize
    public let fixed: Bool
    /// The element has a visible title (a button or sidebar item), so its frame is mostly icon and text.
    public let titled: Bool
    public init(id: String, target: CGRect, size: CGSize, fixed: Bool = false, titled: Bool = false) {
        self.id = id; self.target = target; self.size = size; self.fixed = fixed; self.titled = titled
    }
    /// Where an element's own text or icon probably is, when nothing better is known:
    /// a left-aligned band for wide rows, menu items, and links, otherwise its middle.
    public var estimatedContent: CGRect {
        let t = target
        if t.width > t.height * 2.5 {
            return CGRect(x: t.minX + 6, y: t.minY + t.height * 0.2, width: max(0, t.width * 0.6 - 6), height: t.height * 0.6)
        }
        return t.insetBy(dx: t.width * 0.25, dy: t.height * 0.25)
    }
}

/// The preferred side of the element for its label. Only `.center` may cover the element's text.
public enum HintPosition: String, CaseIterable, Codable {
    case leading, trailing, above, below, center
}

/// Label placement preferences. Offsets are screen points: positive x moves
/// right, positive y moves down, regardless of the layout coordinate space.
public struct HintPlacementStyle: Equatable {
    public var position: HintPosition
    public var offset: CGSize
    /// True for bottom-left-origin (Cocoa) coordinates, false for top-left origin.
    public var yAxisUp: Bool
    public static let gap: CGFloat = 2
    public static let centered = HintPlacementStyle(position: .center)
    public init(position: HintPosition, offset: CGSize = .zero, yAxisUp: Bool = true) {
        self.position = position; self.offset = offset; self.yAxisUp = yAxisUp
    }
    /// The preferred label frame before collision avoidance.
    public func frame(for target: CGRect, size: CGSize) -> CGRect {
        let gap = Self.gap
        var x = target.midX - size.width / 2, y = target.midY - size.height / 2
        let top = yAxisUp ? target.maxY + gap : target.minY - gap - size.height
        let bottom = yAxisUp ? target.minY - gap - size.height : target.maxY + gap
        switch position {
        case .leading: x = target.minX - gap - size.width
        case .trailing: x = target.maxX + gap
        case .above: y = top
        case .below: y = bottom
        case .center: break
        }
        return CGRect(x: x + offset.width, y: y + (yAxisUp ? -offset.height : offset.height), width: size.width, height: size.height)
    }
}

public struct HintPlacement: Equatable {
    public let id: String
    public let frame: CGRect
    public let anchor: CGPoint
    /// Center of the preferred frame; a connector is drawn only when moved away from it.
    public let home: CGPoint
    /// The labelled element's rectangle; zero-sized at the anchor when unknown.
    public let target: CGRect
    public init(id: String, frame: CGRect, anchor: CGPoint, home: CGPoint? = nil, target: CGRect? = nil) {
        self.id = id; self.frame = frame; self.anchor = anchor
        self.home = home ?? anchor
        self.target = target ?? CGRect(origin: anchor, size: .zero)
    }
    /// A label that doesn't touch its element is displaced and gets a connector.
    public var displaced: Bool {
        guard target.width > 0 || target.height > 0 else { return hypot(frame.midX - home.x, frame.midY - home.y) > 1 }
        return !frame.insetBy(dx: -HintPlacementStyle.gap - 1, dy: -HintPlacementStyle.gap - 1).intersects(target)
    }
    public var connectorStart: CGPoint {
        let center = CGPoint(x: frame.midX, y: frame.midY)
        let dx = anchor.x - center.x, dy = anchor.y - center.y
        let scale = min(dx == 0 ? .infinity : frame.width / 2 / abs(dx), dy == 0 ? .infinity : frame.height / 2 / abs(dy), 1)
        return CGPoint(x: center.x + dx * scale, y: center.y + dy * scale)
    }
    func moved(to frame: CGRect) -> HintPlacement { HintPlacement(id: id, frame: frame, anchor: anchor, home: home, target: target) }
}

/// All coordinates use the caller's display coordinate space. Target geometry is never modified.
public enum HintLayout {
    /// Displaced labels farther than this many label heights are strongly discouraged.
    static let reach: CGFloat = 3
    /// Places labels touching their elements without covering `content` (text and icons that must stay
    /// readable). With no content known, each element's `estimatedContent` is kept clear instead.
    /// `icons` are kept clear like text but never treated as an element's main text.
    public static func place(_ items: [HintLayoutItem], in bounds: CGRect, style: HintPlacementStyle = .centered, content: [CGRect] = [], icons: [CGRect] = []) -> [HintPlacement] {
        let ordered = items.sorted { $0.id < $1.id }
        let safe = bounds.insetBy(dx: 4, dy: 4)
        // Grid labels always stay centered in their cells.
        func centered(_ item: HintLayoutItem) -> CGRect {
            (item.fixed ? HintPlacementStyle.centered : style).frame(for: item.target, size: item.size)
        }
        // Element frames: covering another element's padding is only lightly discouraged.
        let elements = ordered.filter { !$0.fixed }.map { ($0.id, $0.target.insetBy(dx: 2, dy: 2)) }
        func area(_ a: CGRect, _ b: CGRect) -> Double {
            let rect = a.intersection(b)
            return rect.isNull ? 0 : rect.width * rect.height
        }
        func constrain(_ frame: CGRect) -> CGRect {
            CGRect(x: min(max(frame.minX, safe.minX), max(safe.minX, safe.maxX - frame.width)),
                   y: min(max(frame.minY, safe.minY), max(safe.minY, safe.maxY - frame.height)), width: frame.width, height: frame.height)
        }
        func overlap(_ a: CGRect, _ b: CGRect) -> Double { area(a.insetBy(dx: -2, dy: -2), b.insetBy(dx: -2, dy: -2)) }
        // Text and icons that labels must not cover.
        // Detected text boxes include padding; trimming them lets labels fit beside text in tight rows.
        let text: [CGRect] = (content.isEmpty ? ordered.filter { !$0.fixed }.map(\.estimatedContent) : content)
            .filter { $0.width > 2 && $0.height > 5 }.map { $0.insetBy(dx: 1, dy: content.isEmpty ? 1 : 2.5) }
        var obstacles = text + icons.filter { $0.width > 2 && $0.height > 2 }.map { $0.insetBy(dx: 1, dy: 1) }
        /// The element's text pieces, first (leftmost on its top line) first.
        func pieces(of t: CGRect, in rects: [CGRect]) -> [CGRect] {
            let inside = t.insetBy(dx: 1, dy: 1)
            return rects.filter { inside.intersects($0) && area(inside, $0) >= Double($0.width * $0.height) / 2 }
                .sorted { abs($0.midY - $1.midY) > min($0.height, $1.height) / 2 ? $0.midY < $1.midY : $0.minX < $1.minX }
        }
        // Detected text misses icons; a control's leading space before its first text usually holds one.
        // An element with no detected text falls back to its estimated content.
        var fallback: [String: CGRect] = [:]
        if !content.isEmpty {
            for item in ordered where !item.fixed {
                let t = item.target
                guard let first = pieces(of: t, in: text).min(by: { $0.minX < $1.minX }) else {
                    // Compact titled controls (sidebar items, buttons) are mostly icon and text: keep all of it clear.
                    let estimate = item.titled && t.height <= 32 && t.width <= 400 ? t : item.estimatedContent
                    if estimate.width > 2 && estimate.height > 2 { fallback[item.id] = estimate; obstacles.append(estimate.insetBy(dx: 1, dy: 1)) }
                    continue
                }
                let lead = first.minX - t.minX
                guard lead >= 12, lead <= max(48, t.height * 2) else { continue }
                let side = min(t.height - 2, max(first.height, 16))
                obstacles.append(CGRect(x: t.minX + 1, y: first.midY - side / 2, width: lead - 3, height: side))
            }
        }
        func gapBetween(_ a: CGRect, _ b: CGRect) -> CGFloat {
            hypot(max(0, max(a.minX - b.maxX, b.minX - a.maxX)), max(0, max(a.minY - b.maxY, b.minY - a.maxY)))
        }
        /// The best spot for one label given the labels placed so far and spots reserved for later ones.
        func search(_ item: HintLayoutItem, placed: [HintPlacement], reserved: [CGRect]) -> (HintPlacement, [Double]) {
            let original = centered(item)
            let anchor = CGPoint(x: item.target.midX, y: item.target.midY)
            let home = CGPoint(x: original.midX, y: original.midY)
            let w = item.size.width, h = item.size.height, gap = HintPlacementStyle.gap
            let t = item.target
            // The element's own text and icons, so its label can sit right next to them.
            let mine = pieces(of: t, in: text)
            // The element's main text: its first piece of text (or its estimate).
            let ownContent = mine.first ?? fallback[item.id] ?? (content.isEmpty && !item.fixed ? item.estimatedContent : nil)
            var frames: [CGRect] = [original]
            if style.position != .center {
                func at(_ x: CGFloat, _ y: CGFloat) -> CGRect { CGRect(x: x, y: y, width: w, height: h) }
                if let c = ownContent {
                    for y in [c.midY - h / 2, t.midY - h / 2] { frames += [at(c.maxX + gap + 1, y), at(c.minX - gap - 1 - w, y)] }
                    for x in [c.minX, c.maxX - w] { frames += [at(x, c.maxY + gap + 1), at(x, c.minY - gap - 1 - h)] }
                }
                let xs = [t.minX + 1, t.midX - w / 2, t.maxX - w - 1], ys = [t.minY + 1, t.midY - h / 2, t.maxY - h - 1]
                // On the element's padding: inner corners and edge midpoints.
                if w + 2 <= t.width && h + 2 <= t.height {
                    for x in xs { for y in ys where !(x == xs[1] && y == ys[1]) { frames.append(at(x, y)) } }
                }
                // Straddling each edge and corner.
                for x in [t.minX - w / 2, t.midX - w / 2, t.maxX - w / 2] { for y in [t.minY - h / 2, t.midY - h / 2, t.maxY - h / 2] where !(x == t.midX - w / 2 && y == t.midY - h / 2) {
                    frames.append(at(x, y))
                } }
                // Flush outside each side, slid along it, and outside the corners.
                for x in [t.minX - gap - w, t.maxX + gap] { for y in ys + [t.minY - h - gap, t.maxY + gap] { frames.append(at(x, y)) } }
                for y in [t.minY - gap - h, t.maxY + gap] { for x in xs { frames.append(at(x, y)) } }
            }
            // Last resort: rings around the preferred spot, in half-label steps; these get a connector.
            for step in [1, 2, 3, 4, 6] {
                for x in -step...step { for y in -step...step where (abs(x) == step || abs(y) == step) && (step < 6 || (x % 2 == 0 && y % 2 == 0)) {
                    frames.append(original.offsetBy(dx: CGFloat(x) / 2 * (w + 4), dy: CGFloat(y) / 2 * (h + 4)))
                } }
            }
            // Nearest to the element first; among touching spots, nearest to the preferred side.
            // Preference: close to the element's own text, then the preferred side.
            var candidates: [(rank: Int, frame: CGRect, distance: CGFloat, preference: CGFloat)] = []
            var region = t
            for (rank, raw) in frames.enumerated() {
                let frame = constrain(raw)
                // Beside the main text on the same line reads best; above or below it is a fallback.
                let near = ownContent.map { c in
                    gapBetween(frame, c) * 4 + (min(frame.maxY, c.maxY) - max(frame.minY, c.minY) >= min(frame.height, c.height) / 2 ? 0 : 40)
                } ?? 0
                // Anything within the standard gap counts as touching.
                let touching = max(0, gapBetween(frame, t) - gap - 1)
                // With the element's text known, the preferred side only breaks ties.
                let side = hypot(frame.midX - home.x, frame.midY - home.y) * (ownContent == nil ? 1 : 0.2)
                candidates.append((rank, frame, touching, near + side))
                region = region.union(frame)
            }
            candidates.sort { a, b in a.distance != b.distance ? a.distance < b.distance : (a.preference != b.preference ? a.preference < b.preference : a.rank < b.rank) }
            region = region.insetBy(dx: -4, dy: -4)
            // Only labels whose label-plus-element box reaches this area can interact.
            let placed = placed.filter { $0.id != item.id && $0.frame.union($0.target).intersects(region) }
            let reserved = reserved.filter { $0.intersects(region) }
            let others = elements.filter { $0.0 != item.id && $0.1.intersects(region) }.map(\.1)
            let own = item.fixed ? t : t.insetBy(dx: 1, dy: 1)
            // "On the element" keeps the label on its own element even over its text.
            let blocked = obstacles.filter { $0.intersects(region) && !(style.position == .center && own.contains($0)) }
            var best: HintPlacement?
            var bestScore: [Double] = []
            for (rank, frame, distance, preference) in candidates {
                // Cost is at least the distance, so no farther candidate can beat a clear best.
                if let first = bestScore.first, first == 0, bestScore[1] == 0, bestScore[2] == 0, bestScore[3] < Double(distance) { break }
                let candidate = HintPlacement(id: item.id, frame: frame, anchor: anchor, home: home, target: t)
                let labelCollisions: Double = placed.reduce(0.0) { $0 + overlap(frame, $1.frame) }
                let collisions: Double = labelCollisions
                let covered: Double = blocked.reduce(0.0) { $0 + area(frame, $1) }
                let crossings = Double(conflicts(candidate, placed))
                let neighbors: Double = others.reduce(0.0) { $0 + area(frame, $1) }
                // Touching the element is free; beyond a few label heights distance is strongly discouraged.
                let travel = Double(distance), limit = Double(reach * (h + 4))
                // Spots later labels prefer are only mildly discouraged; they have alternatives too.
                let claimed: Double = reserved.reduce(0.0) { $0 + overlap(frame, $1) }
                let cost: Double = travel + max(0, travel - limit) * 6 + neighbors * 0.05 + claimed * 0.02 + Double(preference) * 0.01
                let score = [collisions, covered, crossings, cost, Double(rank)]
                if best == nil || score.lexicographicallyPrecedes(bestScore) { best = candidate; bestScore = score }
            }
            return (best!, bestScore)
        }
        var result: [HintPlacement] = []
        for (index, item) in ordered.enumerated() {
            if item.fixed {
                let frame = centered(item)
                result.append(HintPlacement(id: item.id, frame: frame, anchor: CGPoint(x: item.target.midX, y: item.target.midY),
                                            home: CGPoint(x: frame.midX, y: frame.midY), target: item.target)); continue
            }
            // Reserve uncrowded future centers so early labels do not push a collision down a row.
            let reserved = ordered.dropFirst(index + 1).map { constrain(centered($0)) }
            result.append(search(item, placed: result, reserved: reserved).0)
        }
        result = uncross(result)
        // Labels placed early could not see later connectors; re-place any that still conflict.
        // Bounded: on pathologically dense screens, where most labels conflict, it would not converge anyway.
        let conflicting = result.indices.filter { conflicts(result[$0], result, skip: $0) > 0 }.count
        for _ in 0..<(conflicting <= 150 ? 2 : 0) {
            var changed = false
            for (index, item) in ordered.enumerated() where !item.fixed {
                let hint = result[index]
                let near = hint.frame.union(hint.target).insetBy(dx: -2 * hint.frame.width, dy: -2 * hint.frame.width)
                let placed = result.filter { $0.id != hint.id && near.intersects($0.frame.union($0.target)) }
                let crossings = conflicts(hint, placed)
                guard crossings > 0 else { continue }
                let own = item.target.insetBy(dx: 1, dy: 1)
                let covered: Double = obstacles.filter { !(style.position == .center && own.contains($0)) }.reduce(0.0) { $0 + area(hint.frame, $1) }
                let current = [placed.reduce(0.0) { $0 + overlap(hint.frame, $1.frame) }, covered, Double(crossings)]
                let (candidate, score) = search(item, placed: result, reserved: [])
                if Array(score.prefix(3)).lexicographicallyPrecedes(current) { result[index] = candidate; changed = true }
            }
            if !changed { break }
        }
        return result
    }
    /// Text to keep clear: tight visually detected boxes, plus accessibility text frames where
    /// detection found nothing. Accessibility frames are exact in extent but often padded to a
    /// column's width; detection is tight but misses dim or small text.
    public static func textContent(detected: [CGRect], exposed: [CGRect]) -> [CGRect] {
        detected + exposed.filter { frame in
            !detected.contains { box in
                let shared = box.intersection(frame)
                return !shared.isNull && shared.width * shared.height >= box.width * box.height / 2
            }
        }
    }
    /// Swaps same-sized labels whose connectors cross or pass through another label, while that helps.
    static func uncross(_ placements: [HintPlacement]) -> [HintPlacement] {
        var result = placements
        // A connector never leaves the box spanning its label and element.
        func box(_ hint: HintPlacement) -> CGRect { hint.frame.union(hint.target) }
        for _ in 0..<2 {
            var changed = false
            for i in result.indices where result[i].displaced {
                let reach = 2 * result[i].frame.width
                let near = box(result[i]).insetBy(dx: -reach, dy: -reach)
                let nearby = result.indices.filter { $0 != i && near.intersects(box(result[$0])) }
                guard conflicts(result[i], nearby.map { result[$0] }) > 0 else { continue }
                for j in nearby where result[j].displaced && result[i].frame.size == result[j].frame.size {
                    let a = result[i], b = result[j]
                    let area = box(a).union(box(b))
                    let context = result.indices.filter { $0 != i && $0 != j && area.intersects(box(result[$0])) }.map { result[$0] }
                    let before = conflicts(a, context + [b]) + conflicts(b, context)
                    guard before > 0 else { continue }
                    let swappedA = a.moved(to: b.frame), swappedB = b.moved(to: a.frame)
                    if conflicts(swappedA, context + [swappedB]) + conflicts(swappedB, context) < before {
                        result[i] = swappedA; result[j] = swappedB; changed = true
                    }
                }
            }
            if !changed { break }
        }
        return result
    }
    /// Crossings between this label's connector and other connectors or labels, and other connectors through this label.
    static func conflicts(_ hint: HintPlacement, _ others: [HintPlacement], skip: Int? = nil) -> Int {
        var count = 0
        for (index, other) in others.enumerated() where index != skip && other.id != hint.id {
            if hint.displaced {
                if other.displaced && crosses(hint.connectorStart, hint.anchor, other.connectorStart, other.anchor) { count += 1 }
                if segment(hint.connectorStart, hint.anchor, hits: other.frame.insetBy(dx: 1, dy: 1)) { count += 1 }
            }
            if other.displaced && segment(other.connectorStart, other.anchor, hits: hint.frame.insetBy(dx: 1, dy: 1)) { count += 1 }
        }
        return count
    }
    /// Gives neighboring labels different palette indices, so each label and its element read as a pair.
    /// Neighbors are labels whose element and label areas lie within two label sizes of each other.
    public static func colorGroups(_ placements: [HintPlacement], colors: Int = 8) -> [String: Int] {
        let hints = placements.sorted { $0.id < $1.id }
        let areas = hints.map { $0.frame.union($0.target) }
        let neighbors = hints.indices.map { i in
            let reach = 2 * max(hints[i].frame.width, hints[i].frame.height)
            return hints.indices.filter { $0 != i && areas[i].insetBy(dx: -reach, dy: -reach).intersects(areas[$0]) }
        }
        let order = hints.indices.sorted { neighbors[$0].count != neighbors[$1].count ? neighbors[$0].count > neighbors[$1].count : hints[$0].id < hints[$1].id }
        var assigned: [Int: Int] = [:]
        for i in order {
            let used = Set(neighbors[i].compactMap { assigned[$0] })
            if let free = (0..<colors).first(where: { !used.contains($0) }) { assigned[i] = free; continue }
            // Out of colors locally: reuse the color whose nearest use is farthest away.
            func distance(_ color: Int) -> CGFloat {
                assigned.filter { $0.value == color }.map { hypot(areas[$0.key].midX - areas[i].midX, areas[$0.key].midY - areas[i].midY) }.min() ?? .infinity
            }
            assigned[i] = (0..<colors).max { distance($0) < distance($1) }!
        }
        return Dictionary(uniqueKeysWithValues: assigned.map { (hints[$0.key].id, $0.value) })
    }
    private static func crosses(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint, _ d: CGPoint) -> Bool {
        func side(_ p: CGPoint, _ q: CGPoint, _ r: CGPoint) -> CGFloat { (q.x-p.x)*(r.y-p.y) - (q.y-p.y)*(r.x-p.x) }
        return side(a,b,c) * side(a,b,d) < 0 && side(c,d,a) * side(c,d,b) < 0
    }
    private static func segment(_ a: CGPoint, _ b: CGPoint, hits rect: CGRect) -> Bool {
        guard !rect.isEmpty else { return false }
        if rect.contains(a) || rect.contains(b) { return true }
        let corners = [CGPoint(x: rect.minX, y: rect.minY), CGPoint(x: rect.maxX, y: rect.minY), CGPoint(x: rect.maxX, y: rect.maxY), CGPoint(x: rect.minX, y: rect.maxY)]
        return (0..<4).contains { crosses(a, b, corners[$0], corners[($0 + 1) % 4]) }
    }
}

/// Chooses where the status card sits so it does not cover labels, targets, or the pointer.
public enum HUDPlacement {
    /// Returns the first candidate with the least overlap; the first is the preferred spot.
    public static func choose(_ candidates: [CGRect], avoiding avoid: [CGRect], pointer: CGPoint?) -> CGRect? {
        let pointerBox = pointer.map { CGRect(x: $0.x - 40, y: $0.y - 40, width: 80, height: 80) }
        func cost(_ frame: CGRect) -> Double {
            let covered = avoid.reduce(0.0) { total, rect in
                let overlap = frame.intersection(rect)
                return total + (overlap.isNull ? 0 : overlap.width * overlap.height)
            }
            return covered + (pointerBox.map { frame.intersects($0) } == true ? 1e9 : 0)
        }
        var best: (CGRect, Double)?
        for frame in candidates {
            let value = cost(frame)
            if best == nil || value < best!.1 { best = (frame, value) }
            if value == 0 { break }
        }
        return best?.0
    }
}
