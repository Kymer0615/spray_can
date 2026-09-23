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

public struct HintPlacement: Equatable {
    public let id: String
    public let frame: CGRect
    public let anchor: CGPoint
    public var displaced: Bool { hypot(frame.midX - anchor.x, frame.midY - anchor.y) > 1 }
    public var connectorStart: CGPoint {
        let center = CGPoint(x: frame.midX, y: frame.midY)
        let dx = anchor.x - center.x, dy = anchor.y - center.y
        let scale = min(dx == 0 ? .infinity : frame.width / 2 / abs(dx), dy == 0 ? .infinity : frame.height / 2 / abs(dy), 1)
        return CGPoint(x: center.x + dx * scale, y: center.y + dy * scale)
    }
}

/// All coordinates use the caller's display coordinate space. Target geometry is never modified.
public enum HintLayout {
    public static func place(_ items: [HintLayoutItem], in bounds: CGRect) -> [HintPlacement] {
        let ordered = items.sorted { $0.id < $1.id }
        let safe = bounds.insetBy(dx: 4, dy: 4)
        func centered(_ item: HintLayoutItem) -> CGRect {
            CGRect(x: item.target.midX - item.size.width / 2, y: item.target.midY - item.size.height / 2, width: item.size.width, height: item.size.height)
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
            if item.fixed {
                result.append(HintPlacement(id: item.id, frame: original, anchor: anchor)); continue
            }
            let neighbors = ordered.filter { $0.id != item.id && overlap(original, centered($0)) > 0 }
            let vertical = neighbors.reduce(0.0) { $0 + abs($1.target.midY - anchor.y) } >= neighbors.reduce(0.0) { $0 + abs($1.target.midX - anchor.x) }
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
                let candidate = HintPlacement(id: item.id, frame: frame, anchor: anchor)
                let area = result.reduce(0.0) { $0 + overlap(frame, $1.frame) } + reserved.reduce(0.0) { $0 + overlap(frame, $1) }
                let crossings = candidate.displaced ? result.filter { $0.displaced && crosses(candidate.connectorStart, anchor, $0.connectorStart, $0.anchor) }.count : 0
                let distance = hypot(frame.midX - anchor.x, frame.midY - anchor.y)
                // Prefer the perpendicular axis in a cluster, then shortest displacement.
                let axisPenalty = neighbors.isEmpty || (vertical ? offset.1 == 0 : offset.0 == 0) ? 0.0 : 1.0
                let score = [area, Double(crossings), axisPenalty, distance, Double(rank)]
                if best == nil || score.lexicographicallyPrecedes(bestScore) { best = candidate; bestScore = score }
                if area == 0 && !candidate.displaced { break }
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
