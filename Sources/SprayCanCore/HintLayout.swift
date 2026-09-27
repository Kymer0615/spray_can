import Foundation
import CoreGraphics

public struct HintLayoutItem: Equatable {
    public let id: String
    public let target: CGRect
    public let size: CGSize
    public let fixed: Bool
    public init(id: String, target: CGRect, size: CGSize, fixed: Bool = false) {
        self.id = id; self.target = target; self.size = size; self.fixed = fixed
    }
}

/// Where a label sits relative to its element. Only `.center` covers the element.
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
    public init(id: String, frame: CGRect, anchor: CGPoint, home: CGPoint? = nil) {
        self.id = id; self.frame = frame; self.anchor = anchor
        self.home = home ?? anchor
    }
    public var displaced: Bool { hypot(frame.midX - home.x, frame.midY - home.y) > 1 }
    public var connectorStart: CGPoint {
        let center = CGPoint(x: frame.midX, y: frame.midY)
        let dx = anchor.x - center.x, dy = anchor.y - center.y
        let scale = min(dx == 0 ? .infinity : frame.width / 2 / abs(dx), dy == 0 ? .infinity : frame.height / 2 / abs(dy), 1)
        return CGPoint(x: center.x + dx * scale, y: center.y + dy * scale)
    }
}

/// All coordinates use the caller's display coordinate space. Target geometry is never modified.
public enum HintLayout {
    public static func place(_ items: [HintLayoutItem], in bounds: CGRect, style: HintPlacementStyle = .centered) -> [HintPlacement] {
        let ordered = items.sorted { $0.id < $1.id }
        let safe = bounds.insetBy(dx: 4, dy: 4)
        // Grid labels always stay centered in their cells.
        func centered(_ item: HintLayoutItem) -> CGRect {
            (item.fixed ? HintPlacementStyle.centered : style).frame(for: item.target, size: item.size)
        }
        // Covering elements is avoided unless labels are meant to sit on them:
        // first the label's own element, then any other element.
        let elements = ordered.filter { !$0.fixed }.map { $0.target.insetBy(dx: 2, dy: 2) }
        func covers(_ frame: CGRect, _ item: HintLayoutItem) -> Double {
            guard style.position != .center else { return 0 }
            // Exact intersection: a label merely touching an element does not hide it.
            func area(_ element: CGRect) -> Double {
                let rect = frame.intersection(element)
                return rect.isNull ? 0 : rect.width * rect.height
            }
            return area(item.target.insetBy(dx: 2, dy: 2)) * 4 + elements.reduce(0.0) { $0 + area($1) }
        }
        func constrain(_ frame: CGRect) -> CGRect {
            CGRect(x: min(max(frame.minX, safe.minX), max(safe.minX, safe.maxX - frame.width)),
                   y: min(max(frame.minY, safe.minY), max(safe.minY, safe.maxY - frame.height)), width: frame.width, height: frame.height)
        }
        func overlap(_ a: CGRect, _ b: CGRect) -> Double {
            let rect = a.insetBy(dx: -2, dy: -2).intersection(b.insetBy(dx: -2, dy: -2))
            return rect.isNull ? 0 : rect.width * rect.height
        }
        var result: [HintPlacement] = []
        for (index, item) in ordered.enumerated() {
            let original = centered(item)
            let anchor = CGPoint(x: item.target.midX, y: item.target.midY)
            let home = CGPoint(x: original.midX, y: original.midY)
            if item.fixed {
                result.append(HintPlacement(id: item.id, frame: original, anchor: anchor, home: home)); continue
            }
            let neighbors = ordered.filter { $0.id != item.id && overlap(original, centered($0)) > 0 }
            let vertical = neighbors.reduce(0.0) { $0 + abs($1.target.midY - anchor.y) } >= neighbors.reduce(0.0) { $0 + abs($1.target.midX - anchor.x) }
            let constrained = constrain(original)
            var offsets: [(Int, Int)] = [(0, 0)]
            for step in 1...3 {
                offsets += vertical ? [(-step, 0), (step, 0), (0, -step), (0, step)] : [(0, -step), (0, step), (-step, 0), (step, 0)]
                for x in -step...step { for y in -step...step where abs(x) == step || abs(y) == step {
                    if x != 0 && y != 0 { offsets.append((x, y)) }
                } }
            }
            var best: HintPlacement?
            var bestScore: [Double] = []
            // Reserve uncrowded future centers so early labels do not push a collision down a row.
            let reserved = ordered.dropFirst(index + 1).map { constrain(centered($0)) }
            for (rank, offset) in offsets.enumerated() {
                let frame = constrain(original.offsetBy(dx: CGFloat(offset.0) * (item.size.width + 4), dy: CGFloat(offset.1) * (item.size.height + 4)))
                let candidate = HintPlacement(id: item.id, frame: frame, anchor: anchor, home: home)
                let area = result.reduce(0.0) { $0 + overlap(frame, $1.frame) } + reserved.reduce(0.0) { $0 + overlap(frame, $1) }
                let cover = covers(frame, item)
                let crossings = candidate.displaced ? result.filter { $0.displaced && crosses(candidate.connectorStart, anchor, $0.connectorStart, $0.anchor) }.count : 0
                let distance = hypot(frame.midX - home.x, frame.midY - home.y)
                // Prefer the perpendicular axis in a cluster, then shortest displacement.
                let axisPenalty = neighbors.isEmpty || (vertical ? offset.1 == 0 : offset.0 == 0) ? 0.0 : 1.0
                let score = [area, cover, Double(crossings), axisPenalty, distance, Double(rank)]
                if best == nil || score.lexicographicallyPrecedes(bestScore) { best = candidate; bestScore = score }
                if area == 0 && cover == 0 && frame == constrained { break }
            }
            result.append(best!)
        }
        return result
    }
    private static func crosses(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint, _ d: CGPoint) -> Bool {
        func side(_ p: CGPoint, _ q: CGPoint, _ r: CGPoint) -> CGFloat { (q.x-p.x)*(r.y-p.y) - (q.y-p.y)*(r.x-p.x) }
        return side(a,b,c) * side(a,b,d) < 0 && side(c,d,a) * side(c,d,b) < 0
    }
}
