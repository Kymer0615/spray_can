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
    private func covered(_ frame: CGRect, _ content: CGRect) -> Bool {
        let shared = frame.intersection(content.insetBy(dx: 1, dy: 1))
        return !shared.isNull && shared.width * shared.height > 0
    }
    func testLabelsTouchElementsWithoutCoveringTheirContent() {
        let buttons = (0..<4).map { HintLayoutItem(id: "\($0)", target: CGRect(x: 200 + Double($0) * 70, y: 180, width: 40, height: 24), size: CGSize(width: 28, height: 20)) }
        for position in HintPosition.allCases where position != .center {
            for yAxisUp in [true, false] {
                let result = HintLayout.place(buttons, in: bounds, style: HintPlacementStyle(position: position, yAxisUp: yAxisUp))
                assertClear(result, in: bounds)
                for hint in result {
                    let button = buttons.first { $0.id == hint.id }!
                    XCTAssertFalse(covered(hint.frame, button.estimatedContent), "\(position) covers its element's content")
                    XCTAssertFalse(hint.displaced, "Uncrowded labels touch their element")
                }
            }
        }
    }
    func testLabelSitsBesideTheElementsTextNotOnIt() {
        // A wide row with an icon and a short title; text and icon are known.
        let row = HintLayoutItem(id: "row", target: CGRect(x: 100, y: 100, width: 300, height: 24), size: CGSize(width: 28, height: 20))
        let icon = CGRect(x: 104, y: 104, width: 16, height: 16), title = CGRect(x: 126, y: 106, width: 60, height: 12)
        let hint = HintLayout.place([row], in: bounds, style: HintPlacementStyle(position: .leading), content: [title], icons: [icon])[0]
        XCTAssertFalse(covered(hint.frame, title)); XCTAssertFalse(covered(hint.frame, icon))
        XCTAssertFalse(hint.displaced)
        // Right after the title, on the same line.
        XCTAssertEqual(hint.frame.minX, title.maxX + HintPlacementStyle.gap + 1, accuracy: 1)
        XCTAssertLessThan(abs(hint.frame.midY - title.midY), 6)
    }
    func testLeadingIconIsKeptClearWhenOnlyTextIsKnown() {
        let button = HintLayoutItem(id: "b", target: CGRect(x: 100, y: 100, width: 120, height: 24), size: CGSize(width: 28, height: 20))
        let title = CGRect(x: 130, y: 106, width: 60, height: 12)
        let hint = HintLayout.place([button], in: bounds, style: HintPlacementStyle(position: .leading), content: [title])[0]
        XCTAssertFalse(covered(hint.frame, CGRect(x: 102, y: 102, width: 24, height: 20)), "the icon before the title stays visible")
        XCTAssertFalse(covered(hint.frame, title))
    }
    func testTitledControlsWithoutKnownTextKeepTheirFrameClear() {
        let items = [HintLayoutItem(id: "a", target: CGRect(x: 100, y: 100, width: 70, height: 24), size: CGSize(width: 28, height: 20), titled: true),
                     HintLayoutItem(id: "b", target: CGRect(x: 100, y: 140, width: 70, height: 24), size: CGSize(width: 28, height: 20), titled: true)]
        // Text is known elsewhere on screen, but not inside these controls.
        let result = HintLayout.place(items, in: bounds, style: HintPlacementStyle(position: .leading), content: [CGRect(x: 400, y: 300, width: 50, height: 12)])
        for hint in result {
            let target = items.first { $0.id == hint.id }!.target
            XCTAssertFalse(covered(hint.frame, target.insetBy(dx: 1, dy: 1)))
            XCTAssertFalse(hint.displaced)
        }
    }
    func testTextContentPrefersTightDetectedBoxes() {
        let padded = CGRect(x: 74, y: 124, width: 156, height: 18), tight = CGRect(x: 76, y: 126, width: 65, height: 12)
        let missed = CGRect(x: 74, y: 160, width: 156, height: 18)
        XCTAssertEqual(HintLayout.textContent(detected: [tight], exposed: [padded, missed]), [tight, missed])
    }
    func testPositionsAndOffsetsUseScreenDirections() {
        let target = CGRect(x: 100, y: 100, width: 40, height: 20), size = CGSize(width: 20, height: 10)
        let up = HintPlacementStyle(position: .above, yAxisUp: true).frame(for: target, size: size)
        XCTAssertEqual(up.minY, target.maxY + HintPlacementStyle.gap)
        let down = HintPlacementStyle(position: .above, yAxisUp: false).frame(for: target, size: size)
        XCTAssertEqual(down.maxY, target.minY - HintPlacementStyle.gap)
        XCTAssertEqual(HintPlacementStyle(position: .leading).frame(for: target, size: size).maxX, target.minX - HintPlacementStyle.gap)
        XCTAssertEqual(HintPlacementStyle(position: .trailing).frame(for: target, size: size).minX, target.maxX + HintPlacementStyle.gap)
        // Positive offsets move right and down on screen in either coordinate space.
        let base = HintPlacementStyle(position: .leading).frame(for: target, size: size)
        let moved = HintPlacementStyle(position: .leading, offset: CGSize(width: 5, height: 7)).frame(for: target, size: size)
        XCTAssertEqual(moved.minX - base.minX, 5); XCTAssertEqual(moved.minY - base.minY, -7)
        let flipped = HintPlacementStyle(position: .leading, offset: CGSize(width: 5, height: 7), yAxisUp: false).frame(for: target, size: size)
        XCTAssertEqual(flipped.minY - base.minY, 7)
        XCTAssertEqual(HintPlacementStyle.centered.frame(for: target, size: size).midX, target.midX)
    }
    func testLabelsAtTheScreenEdgeMoveOffTheirElement() {
        let edge = HintLayoutItem(id: "edge", target: CGRect(x: 4, y: 180, width: 60, height: 24), size: CGSize(width: 28, height: 20))
        let hint = HintLayout.place([edge], in: bounds, style: HintPlacementStyle(position: .leading))[0]
        XCTAssertTrue(bounds.insetBy(dx: 4, dy: 4).contains(hint.frame))
        XCTAssertFalse(covered(hint.frame, edge.estimatedContent))
    }
    func testGridLabelsStayCenteredInTheirCells() {
        let cell = HintLayoutItem(id: "cell", target: CGRect(x: 100, y: 100, width: 80, height: 80), size: CGSize(width: 28, height: 20), fixed: true)
        let hint = HintLayout.place([cell], in: bounds, style: HintPlacementStyle(position: .leading, offset: CGSize(width: 9, height: 9)))[0]
        XCTAssertEqual(hint.frame.midX, cell.target.midX); XCTAssertEqual(hint.frame.midY, cell.target.midY)
    }
    /// Items on a square lattice, filled row by row.
    private func lattice(_ prefix: String, count: Int, columns: Int, x: Double, y: Double, pitch: Double) -> [HintLayoutItem] {
        (0..<count).map { (index: Int) -> HintLayoutItem in
            let column = Double(index % columns), row = Double(index / columns)
            return item("\(prefix)\(index)", x + column * pitch, y + row * pitch)
        }
    }
    private func crossings(_ placements: [HintPlacement]) -> Int {
        placements.reduce(0) { $0 + HintLayout.conflicts($1, placements) }
    }
    func testConnectorsDoNotCrossInClusters() {
        let clusters: [[HintLayoutItem]] = [
            lattice("v", count: 6, columns: 1, x: 200, y: 150, pitch: 10),
            lattice("h", count: 6, columns: 6, x: 150, y: 200, pitch: 12),
            lattice("g", count: 9, columns: 3, x: 200, y: 180, pitch: 12),
        ]
        for items in clusters {
            for style in [HintPlacementStyle.centered, HintPlacementStyle(position: .leading)] {
                let result = HintLayout.place(items, in: bounds, style: style)
                assertClear(result, in: bounds)
                XCTAssertEqual(crossings(result), 0, "\(items.map(\.id)) \(style.position)")
                XCTAssertEqual(result, HintLayout.place(items.reversed(), in: bounds, style: style))
            }
        }
    }
    func testDisplacedLabelsStayCloseToTheirElements() {
        let row = (0..<8).map { HintLayoutItem(id: "\($0)", target: CGRect(x: 100 + Double($0) * 30, y: 200, width: 24, height: 24), size: CGSize(width: 28, height: 20)) }
        let result = HintLayout.place(row, in: bounds, style: HintPlacementStyle(position: .leading))
        assertClear(result, in: bounds)
        for hint in result {
            XCTAssertLessThanOrEqual(hypot(hint.frame.midX - hint.anchor.x, hint.frame.midY - hint.anchor.y), 3 * 24 + 30, hint.id)
        }
    }
    func testNeighborsGetDistinctColors() {
        let cluster = lattice("c", count: 8, columns: 4, x: 200, y: 200, pitch: 14)
        let spread = lattice("s", count: 4, columns: 4, x: 40, y: 360, pitch: 150)
        let placements = HintLayout.place(cluster + spread, in: bounds, style: HintPlacementStyle(position: .leading))
        let colors = HintLayout.colorGroups(placements)
        XCTAssertEqual(Set(cluster.compactMap { colors[$0.id] }).count, 8)
        XCTAssertEqual(colors.count, placements.count)
        XCTAssertTrue(colors.values.allSatisfy { (0..<8).contains($0) })
        XCTAssertEqual(colors, HintLayout.colorGroups(placements.reversed()))
        // Adjacent buttons in a row differ even when no label moved.
        let row = (0..<4).map { HintLayoutItem(id: "\($0)", target: CGRect(x: 200 + Double($0) * 70, y: 180, width: 40, height: 24), size: CGSize(width: 28, height: 20)) }
        let rowColors = HintLayout.colorGroups(HintLayout.place(row, in: bounds, style: HintPlacementStyle(position: .leading)))
        for index in 1..<4 { XCTAssertNotEqual(rowColors["\(index)"], rowColors["\(index - 1)"]) }
    }
    func testHUDMovesAwayFromLabelsAndPointer() {
        let bottom = CGRect(x: 280, y: 24, width: 440, height: 76), top = CGRect(x: 280, y: 900, width: 440, height: 76)
        XCTAssertEqual(HUDPlacement.choose([bottom, top], avoiding: [CGRect(x: 0, y: 400, width: 50, height: 50)], pointer: CGPoint(x: 500, y: 500)), bottom)
        XCTAssertEqual(HUDPlacement.choose([bottom, top], avoiding: [CGRect(x: 300, y: 40, width: 30, height: 20)], pointer: nil), top)
        XCTAssertEqual(HUDPlacement.choose([bottom, top], avoiding: [], pointer: CGPoint(x: 500, y: 60)), top)
        XCTAssertNil(HUDPlacement.choose([], avoiding: [], pointer: nil))
    }
    func testLabColorsAndPaletteSeparation() {
        let white = LabColor(hex: "FFFFFF"), red = LabColor(hex: "FF0000")
        XCTAssertEqual(white.l, 100, accuracy: 0.1); XCTAssertEqual(white.a, 0, accuracy: 0.1); XCTAssertEqual(white.b, 0, accuracy: 0.1)
        XCTAssertEqual(red.l, 53.2, accuracy: 0.3); XCTAssertEqual(red.a, 80.1, accuracy: 0.5); XCTAssertEqual(red.b, 67.2, accuracy: 0.5)
        let palette = LabColor.labelPalette.map(LabColor.init(hex:))
        for (i, a) in palette.enumerated() { for b in palette.dropFirst(i + 1) { XCTAssertGreaterThan(a.distance(to: b), 30) } }
    }
    func testNearestNeighborsGetTheMostContrastingColors() {
        let palette = LabColor.labelPalette.map(LabColor.init(hex:))
        // A dense toolbar and a list: plenty of neighbors at different distances.
        let toolbar = (0..<10).map { HintLayoutItem(id: "t\($0)", target: CGRect(x: 40 + Double($0) * 34, y: 40, width: 28, height: 24), size: CGSize(width: 28, height: 20)) }
        let list = (0..<10).map { HintLayoutItem(id: "l\($0)", target: CGRect(x: 60, y: 90 + Double($0) * 26, width: 200, height: 22), size: CGSize(width: 28, height: 20)) }
        let placements = HintLayout.place(toolbar + list, in: bounds, style: HintPlacementStyle(position: .leading))
        let colors = HintLayout.colorGroups(placements)
        XCTAssertEqual(colors, HintLayout.colorGroups(placements.reversed()))
        func area(_ p: HintPlacement) -> CGRect { p.frame.union(p.target) }
        for p in placements {
            let others = placements.filter { $0.id != p.id }
            func gap(_ o: HintPlacement) -> CGFloat {
                let a = area(p), b = area(o)
                return hypot(max(0, max(a.minX - b.maxX, b.minX - a.maxX)), max(0, max(a.minY - b.maxY, b.minY - a.maxY)))
            }
            let nearest = others.min { gap($0) < gap($1) }!
            let difference = palette[colors[p.id]!].distance(to: palette[colors[nearest.id]!])
            XCTAssertGreaterThan(difference, 45, "\(p.id) and its nearest neighbor \(nearest.id) look alike")
        }
    }
    func testEveryColorSchemeKeepsNeighborsDistinct() {
        XCTAssertEqual(Set(LabelColorScheme.all.map(\.id)).count, LabelColorScheme.all.count)
        XCTAssertEqual(LabelColorScheme.named("missing"), .vivid)
        let toolbar = (0..<10).map { HintLayoutItem(id: "t\($0)", target: CGRect(x: 40 + Double($0) * 34, y: 40, width: 28, height: 24), size: CGSize(width: 28, height: 20)) }
        let placements = HintLayout.place(toolbar, in: bounds, style: HintPlacementStyle(position: .leading))
        for scheme in LabelColorScheme.all {
            XCTAssertEqual(scheme.hexes.count, 8, scheme.id)
            XCTAssertTrue(scheme.hexes.allSatisfy { AppearanceColor.label.validated($0) == $0.uppercased() }, scheme.id)
            let lab = scheme.lab
            // Pastels are inherently close; every other scheme is well separated.
            let floor = scheme == .pastel ? 15.0 : 25.0
            for (i, a) in lab.enumerated() { for b in lab.dropFirst(i + 1) { XCTAssertGreaterThan(a.distance(to: b), floor, scheme.id) } }
            let colors = HintLayout.colorGroups(placements, palette: lab)
            for index in 1..<10 {
                let difference = lab[colors["t\(index)"]!].distance(to: lab[colors["t\(index - 1)"]!])
                XCTAssertGreaterThan(difference, floor, "\(scheme.id): adjacent toolbar labels look alike")
            }
        }
    }
}
