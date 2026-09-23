import XCTest
@testable import SprayCanCore

final class HintLayoutTests: XCTestCase {
    private let bounds = CGRect(x: 0, y: 0, width: 600, height: 400)
    private func item(_ id: String, _ x: Double, _ y: Double, fixed: Bool = false) -> HintLayoutItem {
        HintLayoutItem(id: id, target: CGRect(x: x - 4, y: y - 4, width: 8, height: 8), size: CGSize(width: 32, height: 22), fixed: fixed)
    }
    private func assertClear(_ placements: [HintPlacement], in bounds: CGRect, file: StaticString = #filePath, line: UInt = #line) {
        for (index, hint) in placements.enumerated() {
            XCTAssertTrue(bounds.insetBy(dx: 4, dy: 4).contains(hint.frame), file: file, line: line)
            for other in placements.dropFirst(index + 1) {
                let overlap = hint.frame.insetBy(dx: -1.99, dy: -1.99).intersection(other.frame.insetBy(dx: -1.99, dy: -1.99))
                XCTAssertTrue(overlap.isNull || overlap.width * overlap.height == 0, file: file, line: line)
            }
        }
    }
    func testVerticalAndHorizontalClusters() {
        for vertical in [true, false] {
            let items = (0..<5).map { item("\($0)", vertical ? 200 : 160 + Double($0) * 15, vertical ? 160 + Double($0) * 12 : 200) }
            let result = HintLayout.place(items, in: bounds)
            assertClear(result, in: bounds)
            XCTAssertTrue(result.contains(where: \.displaced))
            XCTAssertEqual(result, HintLayout.place(items.reversed(), in: bounds))
            for hint in result {
                let original = items.first { $0.id == hint.id }!
                XCTAssertEqual(hint.anchor, CGPoint(x: original.target.midX, y: original.target.midY))
            }
        }
    }
    func testMixedCoincidentAndEdgeTargets() {
        for center in [CGPoint(x: 200, y: 200), CGPoint(x: 5, y: 5), CGPoint(x: 595, y: 395)] {
            let items = [item("a", center.x, center.y), item("b", center.x, center.y), item("c", center.x + (center.x > 300 ? -12 : 12), center.y)]
            assertClear(HintLayout.place(items, in: bounds), in: bounds)
        }
    }
    func testDisplayTranslationAndGridCenters() {
        let items = [item("a", 200, 200), item("b", 210, 200)]
        let baseline = HintLayout.place(items, in: bounds)
        let shifted = items.map { HintLayoutItem(id: $0.id, target: $0.target.offsetBy(dx: -800, dy: 300), size: $0.size) }
        let result = HintLayout.place(shifted, in: bounds.offsetBy(dx: -800, dy: 300))
        XCTAssertEqual(result.map(\.frame), baseline.map { $0.frame.offsetBy(dx: -800, dy: 300) })
        let grid = HintLayout.place([item("grid", 20, 20, fixed: true)], in: bounds)
        XCTAssertFalse(grid[0].displaced)
    }
    func testFilteringRetainsFullSetLayoutAndConnectors() {
        let items = [item("aa", 100, 100), item("ab", 110, 100), item("ba", 120, 100)]
        let full = HintLayout.place(items, in: bounds)
        let filtered = full.filter { $0.id.hasPrefix("a") }
        XCTAssertEqual(filtered.map(\.frame), Array(full.prefix(2)).map(\.frame))
        for hint in full where hint.displaced {
            let p = hint.connectorStart
            XCTAssertTrue(abs(p.x - hint.frame.minX) < 0.001 || abs(p.x - hint.frame.maxX) < 0.001 || abs(p.y - hint.frame.minY) < 0.001 || abs(p.y - hint.frame.maxY) < 0.001)
        }
    }
    func testImpossibleDensityKeepsEveryTargetDeterministically() {
        let items = (0..<25).map { item("\($0)", 20, 20) }
        let small = CGRect(x: 0, y: 0, width: 50, height: 50)
        let result = HintLayout.place(items, in: small)
        XCTAssertEqual(result.count, items.count)
        XCTAssertEqual(result, HintLayout.place(items, in: small))
        XCTAssertTrue(result.allSatisfy { small.insetBy(dx: 4, dy: 4).contains($0.frame) })
    }
}
