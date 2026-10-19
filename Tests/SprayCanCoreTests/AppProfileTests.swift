import XCTest
@testable import SprayCanCore

final class AppProfileTests: XCTestCase {
    func testAppsWithoutProfilesFollowGlobalSettings() {
        let behavior = AppBehavior.resolve(bundleID: "com.example.none", profiles: [:], vision: true, prescan: true)
        XCTAssertEqual(behavior, AppBehavior(ocr: true, prescan: true, scanTime: .normal))
        XCTAssertEqual(AppBehavior.resolve(bundleID: nil, profiles: [:], vision: false, prescan: true),
                       AppBehavior(ocr: false, prescan: false, scanTime: .normal))
    }

    func testProfilesOverrideGlobalSettings() {
        let profiles = ["code": AppProfile(name: "Code", ocr: .off),
                        "spotify": AppProfile(name: "Spotify", ocr: .on, prescan: .on),
                        "finder": AppProfile(name: "Finder", scanTime: .extended)]
        XCTAssertFalse(AppBehavior.resolve(bundleID: "code", profiles: profiles, vision: true, prescan: true).ocr)
        // OCR off also stops reading ahead, whatever the prescan choice.
        XCTAssertFalse(AppBehavior.resolve(bundleID: "code", profiles: profiles, vision: true, prescan: true).prescan)
        XCTAssertEqual(AppBehavior.resolve(bundleID: "spotify", profiles: profiles, vision: false, prescan: false),
                       AppBehavior(ocr: true, prescan: true, scanTime: .normal))
        XCTAssertEqual(AppBehavior.resolve(bundleID: "finder", profiles: profiles, vision: true, prescan: false),
                       AppBehavior(ocr: true, prescan: false, scanTime: .extended))
        XCTAssertGreaterThan(ScanTime.extended.budget.first, ScanTime.normal.budget.first)
        XCTAssertGreaterThan(ScanTime.extended.budget.retry, ScanTime.normal.budget.retry)
    }

    func testProfilesRoundTripAndTolerateMissingOrUnknownFields() {
        let profiles = ["a": AppProfile(name: "A", ocr: .off, scanTime: .extended)]
        XCTAssertEqual(AppBehavior.decode(AppBehavior.encode(profiles)), profiles)
        let older = AppBehavior.decode(#"{"b":{"name":"B","ocr":"on"},"c":{"name":"C","ocr":"sometimes","future":1}}"#)
        XCTAssertEqual(older["b"], AppProfile(name: "B", ocr: .on))
        XCTAssertEqual(older["c"], AppProfile(name: "C"))
        XCTAssertTrue(older["c"]!.isDefault)
        XCTAssertEqual(AppBehavior.decode("not json"), [:])
    }
}
