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
}
