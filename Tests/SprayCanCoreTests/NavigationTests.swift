import XCTest
import CoreGraphics
@testable import SprayCanCore

final class NavigationTests: XCTestCase {
    func targets(_ count: Int) -> [Target] {
        (0..<count).map { Target(id: "\($0)", frame: CGRect(x: $0 * 10, y: 0, width: 8, height: 8), source: .accessibility) }
    }
    func testThousandImmediateActivationCyclesLoseNoInput() {
        var session = NavigationSession()
        let sample = targets(120)
        let expected = HintLabels.assign(sample)
        for cycle in 0..<1000 {
            let generation = session.begin(.elements)
            let target = expected[cycle % expected.count]
            for character in target.label { XCTAssertEqual(session.type(character), .buffered) }
            let outcomes = session.publish(sample, generation: generation)
            XCTAssertEqual(outcomes.filter { if case .selected = $0 { return true }; return false }, [.selected(target)])
            XCTAssertEqual(session.prefix, "")
            session.cancel()
        }
    }
    func testOldDiscoveryCannotReplaceNewSession() {
        var session = NavigationSession()
        let old = session.begin(.elements)
        let new = session.begin(.grid)
        XCTAssertEqual(session.publish(targets(5), generation: old), [])
        XCTAssertEqual(session.phase, .discovering)
        _ = session.publish(targets(2), generation: new)
        XCTAssertEqual(session.targets.count, 2)
        session.cancel()
        _ = session.publish(targets(8), generation: new)
        XCTAssertEqual(session.phase, .idle)
        XCTAssertTrue(session.targets.isEmpty)
    }
    func testLateVisionCannotRelabelAfterTypingOrSelection() {
        var session = NavigationSession()
        let generation = session.begin(.elements)
        _ = session.publish(targets(30), generation: generation)
        let original = session.targets
        _ = session.type("a")
        _ = session.publish(targets(100), generation: generation)
        XCTAssertEqual(session.targets, original)
        _ = session.type("a")
        _ = session.publish(targets(100), generation: generation)
        XCTAssertEqual(session.targets, original)
    }
    func testCancelClearsPrefixBeforeExiting() {
        var session = NavigationSession()
        let generation = session.begin(.elements)
        _ = session.publish(targets(40), generation: generation)
        _ = session.type("a")
        XCTAssertEqual(session.escape(), .filtered)
        XCTAssertEqual(session.phase, .ready)
        XCTAssertEqual(session.escape(), .cancelled)
        XCTAssertEqual(session.phase, .idle)
    }
    func testActivationModifierReleaseAndRepress() {
        var tracking = ActivationModifiers()
        tracking.begin([.command, .shift])
        XCTAssertEqual(tracking.labelModifiers([.command, .shift]), [])
        tracking.observe(.shift)
        XCTAssertEqual(tracking.labelModifiers(.shift), [])
        tracking.observe([])
        tracking.observe(.command)
        XCTAssertEqual(tracking.labelModifiers(.command), .command)
    }
    func testLabelUniquenessPrefixFreedomAndViReservations() {
        for count in [0, 1, 24, 25, 26, 200, 1400, 3000] {
            let labels = HintLabels.assign(targets(count), vi: true).map(\.label)
            XCTAssertEqual(Set(labels).count, count)
            XCTAssertLessThanOrEqual(Set(labels.map(\.count)).count, 1)
            XCTAssertFalse(labels.contains { $0.contains(where: { "hjkl".contains($0) }) })
        }
    }
    func testMixedDisplayGridAndCoordinateRoundTrip() {
        let screens = [CGRect(x: 0, y: 0, width: 1512, height: 982), CGRect(x: -1920, y: -200, width: 1920, height: 1080)]
        let grid = Geometry.grid(screens: screens, cellSize: 100)
        XCTAssertTrue(grid.allSatisfy { target in screens.contains { $0.contains(target.frame) } })
        XCTAssertEqual(Set(grid.map(\.id)).count, grid.count)
        for screen in screens {
            let cocoa = Geometry.cocoa(screen, primaryHeight: 982)
            XCTAssertEqual(Geometry.cocoa(cocoa, primaryHeight: 982), screen)
        }
    }
    func testOCRMergePreservesAccessibilityAndAddsUncoveredText() {
        let accessible = Target(id: "button", frame: CGRect(x: 10, y: 10, width: 100, height: 40), source: .accessibility)
        let duplicate = Target(id: "text", frame: CGRect(x: 30, y: 20, width: 40, height: 10), source: .text)
        let missing = Target(id: "missing", frame: CGRect(x: 300, y: 20, width: 40, height: 10), source: .text)
        XCTAssertEqual(Geometry.merge([accessible], [duplicate, missing]), [accessible, missing])
    }
    func testCompatibilityClickAndPresentationShortcuts() {
        XCTAssertEqual(KeyMap.action(code: 36, text: "", modifiers: .shift, vi: false), .click(0))
        XCTAssertEqual(KeyMap.action(code: 42, text: "\\", modifiers: [], vi: false), .doubleClick)
        XCTAssertEqual(KeyMap.action(code: 24, text: "=", modifiers: [.control, .shift], vi: false), .toggleLabels)
        XCTAssertEqual(KeyMap.action(code: 24, text: "=", modifiers: [.command, .shift], vi: false), .cellSize(1))
        XCTAssertEqual(KeyMap.action(code: 126, text: "", modifiers: .shift, vi: false), .scroll(0, -1))
        XCTAssertEqual(KeyMap.action(code: 38, text: "j", modifiers: [], vi: true), .move(0, 1, false))
        XCTAssertEqual(KeyMap.action(code: 38, text: "j", modifiers: [], vi: false), .label("j"))
    }
    func testOCRTextOnKnownElementsIsDropped() {
        let button = Target(id: "button", frame: CGRect(x: 100, y: 100, width: 60, height: 24), source: .accessibility, title: "Save")
        let icon = Target(id: "icon", frame: CGRect(x: 200, y: 100, width: 20, height: 20), source: .accessibility, title: "Share")
        let toolbar = Target(id: "toolbar", frame: CGRect(x: 0, y: 0, width: 800, height: 40), source: .accessibility, title: "Toolbar")
        func text(_ id: String, _ frame: CGRect, _ title: String) -> Target { Target(id: id, frame: frame, source: .text, title: title) }
        let inside = text("inside", CGRect(x: 104, y: 98, width: 70, height: 28), "Save")
        let beside = text("beside", CGRect(x: 224, y: 102, width: 40, height: 16), "share")
        let body = text("body", CGRect(x: 300, y: 300, width: 120, height: 16), "Paragraph")
        // Centered in a large element but mostly outside it: not that element's own text.
        let edge = text("edge", CGRect(x: 400, y: 30, width: 60, height: 40), "Tools")
        let far = text("far", CGRect(x: 600, y: 500, width: 40, height: 16), "Save")
        let merged = Geometry.mergeText([button, icon, toolbar], [inside, beside, body, far, edge])
        XCTAssertEqual(merged.map(\.id), ["button", "icon", "toolbar", "body", "far", "edge"])
        // The plain merge keeps text beside an element.
        XCTAssertTrue(Geometry.merge([button, icon], [beside]).contains { $0.id == "beside" })
    }
    func testSpaceHoldsAndLabelsStillMatchWhileHolding() {
        XCTAssertEqual(KeyMap.action(code: 49, text: "", modifiers: [], vi: false), .hold)
        XCTAssertEqual(KeyMap.action(code: 49, text: "", modifiers: [], vi: true), .hold)
        XCTAssertEqual(KeyMap.action(code: 49, text: "", modifiers: .command, vi: false), .none)
        var session = NavigationSession()
        let generation = session.begin(.grid)
        _ = session.publish(targets(30), generation: generation)
        let first = session.targets[3], second = session.targets[20]
        for character in first.label { _ = session.type(character) }
        var last: NavigationSession.Outcome = .ignored
        for character in second.label { last = session.type(character) }
        XCTAssertEqual(last, .selected(second))
    }
    func testRowsWrappingOneControlAndNearDuplicateWrappersCollapse() {
        func target(_ id: String, _ role: String, _ frame: CGRect, title: String = "") -> Target { Target(id: id, frame: frame, source: .accessibility, title: title, role: role) }
        let row = target("row", "AXRow", CGRect(x: 0, y: 0, width: 215, height: 32))
        let button = target("button", "AXButton", CGRect(x: 17, y: 4, width: 88, height: 24), title: "Bluetooth")
        let folder = target("folder", "AXRow", CGRect(x: 0, y: 70, width: 400, height: 20))
        let opener = target("opener", "AXDisclosureTriangle", CGRect(x: 2, y: 72, width: 12, height: 16))
        let listRow = target("list", "AXRow", CGRect(x: 0, y: 40, width: 400, height: 20))
        let triangle = target("tri", "AXDisclosureTriangle", CGRect(x: 2, y: 42, width: 12, height: 16))
        let toggle = target("toggle", "AXCheckBox", CGRect(x: 360, y: 42, width: 30, height: 16))
        let wrapper = target("wrap", "AXGroup", CGRect(x: 500, y: 0, width: 42, height: 26))
        let inner = target("inner", "AXButton", CGRect(x: 501, y: 1, width: 40, height: 24))
        let kept = TargetCollection.collapsed([row, button, listRow, triangle, toggle, wrapper, inner, folder, opener]).map(\.id)
        // A folder row holding only its untitled disclosure triangle keeps its own label.
        XCTAssertEqual(kept, ["button", "list", "tri", "toggle", "inner", "folder", "opener"])
    }
    func testScrollSignFollowsNaturalScrolling() {
        // Down and right are positive in; macOS flips synthesized wheel events when natural scrolling is on.
        XCTAssertTrue(ScrollDirection.wheelDeltas(x: 0, y: 55, natural: false) == (-55, 0))
        XCTAssertTrue(ScrollDirection.wheelDeltas(x: 0, y: 55, natural: true) == (55, 0))
        XCTAssertTrue(ScrollDirection.wheelDeltas(x: 40, y: -30, natural: false) == (30, -40))
        XCTAssertTrue(ScrollDirection.wheelDeltas(x: 40, y: -30, natural: true) == (-30, 40))
        XCTAssertTrue(ScrollDirection.wheelDeltas(x: 0, y: 100_000_000_000, natural: true).vertical == Int32.max)
    }
}
