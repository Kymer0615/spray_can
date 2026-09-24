import XCTest
@testable import SprayCanCore
final class TargetIdentityTests: XCTestCase {
    struct Colliding: Hashable { let value: Int; func hash(into hasher: inout Hasher) { hasher.combine(0) } }
    func testHashCollisionKeepsDistinctIdentitiesAndMapping() {
        var ids = DiscoveryIdentity<Colliding>(namespace: "scan-1")
        let a = ids.id(for: Colliding(value: 1)), b = ids.id(for: Colliding(value: 2))
        XCTAssertNotEqual(a, b)
        XCTAssertEqual(a, ids.id(for: Colliding(value: 1)))
        let mapping = [a: 1, b: 2]
        XCTAssertEqual(mapping[a], 1); XCTAssertEqual(mapping[b], 2)
    }
    func testDuplicateIDsAreRemovedBeforeLabelsAndLayout() {
        let target = Target(id: "repeat", frame: CGRect(x: 0, y: 0, width: 30, height: 20), source: .accessibility)
        var session = NavigationSession(); let generation = session.begin(.elements)
        _ = session.publish([target, target], generation: generation)
        XCTAssertEqual(session.targets.count, 1)
        XCTAssertEqual(session.type(Character(session.targets[0].label)), .selected(session.targets[0]))
    }
    func testOrderingIsTransitiveAndIndependentOfInput() {
        let targets = [("a", 30.0, 0.0), ("b", 20.0, 7.0), ("c", 10.0, 14.0)].map {
            Target(id: $0.0, frame: CGRect(x: $0.1, y: $0.2, width: 10, height: 10), source: .accessibility)
        }
        XCTAssertEqual(TargetCollection.ordered(targets).map(\.id), ["a", "b", "c"])
        XCTAssertEqual(TargetCollection.ordered(targets.reversed()), TargetCollection.ordered(targets))
    }
}
