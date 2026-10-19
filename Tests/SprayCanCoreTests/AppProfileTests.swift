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

final class AppAdaptationTests: XCTestCase {
    func testKindFromBundleFrameworks() {
        XCTAssertEqual(AppKind.detect(frameworks: ["Electron Framework.framework", "Squirrel.framework"]), .electron)
        XCTAssertEqual(AppKind.detect(frameworks: ["Chromium Embedded Framework.framework"]), .cef)
        XCTAssertEqual(AppKind.detect(frameworks: ["AppCenter.framework", "MSWebView2.framework"]), .webView2)
        XCTAssertEqual(AppKind.detect(frameworks: ["Google Chrome Framework.framework"]), .chromium)
        XCTAssertEqual(AppKind.detect(frameworks: ["QtCore.framework"]), .qt)
        XCTAssertEqual(AppKind.detect(frameworks: []), .native)
        XCTAssertTrue(AppKind.webView2.enhanceable)
        XCTAssertFalse(AppKind.cef.enhanceable)
        XCTAssertTrue(AppKind.cef.relaunchable)
        XCTAssertFalse(AppKind.electron.relaunchable)
        XCTAssertFalse(AppKind.electron.enhanceable)
        XCTAssertFalse(AppKind.native.enhanceable)
    }

    private func analysis(_ kind: AppKind, labels: Int = 40, coverage: Double?, lines: Int = 15, ms: Int = 100,
                          truncated: Bool = false, supported: Bool = true) -> AppAnalysis {
        AppAnalysis(kind: kind, labels: labels, coverage: coverage, textLines: lines, scanMilliseconds: ms, truncated: truncated, enhanceSupported: supported)
    }

    func testAdviceMatchesMeasuredApps() {
        let plain = AppBehavior(ocr: false, prescan: false, scanTime: .normal)
        // Teams: web-based, poorly covered, switch settable; text recognition offered too.
        XCTAssertEqual(AppAdvice.recommend(analysis(.webView2, labels: 34, coverage: 0.2), current: plain), [.enhance, .ocr])
        XCTAssertEqual(AppAdvice.recommend(analysis(.webView2, labels: 34, coverage: 0.5), current: plain), [.enhance])
        // Spotify (CEF): relaunch with full accessibility, and read text as a fallback.
        XCTAssertEqual(AppAdvice.recommend(analysis(.cef, labels: 3, coverage: 0), current: plain), [.relaunch, .ocr])
        XCTAssertEqual(AppAdvice.recommend(analysis(.cef, labels: 3, coverage: 0), current: AppBehavior(ocr: true, prescan: false, scanTime: .normal, launchAccessibility: true)), [])
        XCTAssertFalse(analysis(.cef, labels: 3, coverage: 0).readsWell)
        XCTAssertTrue(analysis(.cef, labels: 161, coverage: 1).readsWell)
        // Reminders, Chrome: already good.
        XCTAssertEqual(AppAdvice.recommend(analysis(.native, coverage: 1), current: plain), [])
        XCTAssertEqual(AppAdvice.recommend(analysis(.chromium, labels: 115, coverage: 0.9), current: plain), [])
        // Slow or cut-off scans get more time.
        XCTAssertEqual(AppAdvice.recommend(analysis(.native, coverage: 0.9, ms: 2000, truncated: true), current: plain), [.extendScan])
        // Too few lines to judge: no OCR suggestion.
        XCTAssertEqual(AppAdvice.recommend(analysis(.native, coverage: 0, lines: 3), current: plain), [])
        // What is already in effect is not suggested again.
        let adapted = AppBehavior(ocr: true, prescan: false, scanTime: .extended, enhanced: true)
        XCTAssertEqual(AppAdvice.recommend(analysis(.webView2, labels: 34, coverage: 0.2, ms: 2000), current: adapted), [])
    }

    func testEnhancementKeptOnlyWhenItHelps() {
        let before = analysis(.webView2, labels: 34, coverage: 0.2)
        XCTAssertTrue(Enhancement.worthKeeping(before: before, after: analysis(.webView2, labels: 71, coverage: 0.9)))
        XCTAssertTrue(Enhancement.worthKeeping(before: before, after: analysis(.webView2, labels: 34, coverage: 0.4)))
        XCTAssertFalse(Enhancement.worthKeeping(before: before, after: analysis(.webView2, labels: 36, coverage: 0.25)))
    }

    func testCoverageCountsLinesInsideTargets() {
        let targets = [CGRect(x: 0, y: 0, width: 100, height: 30)]
        XCTAssertEqual(AppAnalysis.coverage(lines: [CGRect(x: 10, y: 10, width: 50, height: 10), CGRect(x: 10, y: 200, width: 50, height: 10)], targets: targets), 0.5)
        XCTAssertNil(AppAnalysis.coverage(lines: [], targets: targets))
    }

    func testPruningKeepsControlsAndOneLabelPerRow() {
        let window = CGRect(x: 0, y: 0, width: 1500, height: 1000)
        func target(_ id: String, _ role: String, _ frame: CGRect) -> Target { Target(id: id, frame: frame, source: .accessibility, role: role) }
        let targets = [
            target("pane", "AXGroup", CGRect(x: 0, y: 0, width: 400, height: 1000)),        // huge wrapper
            target("row", "AXGroup", CGRect(x: 10, y: 100, width: 380, height: 60)),        // a chat row
            target("rowText", "AXStaticText", CGRect(x: 60, y: 110, width: 200, height: 20)),
            target("rowInner", "AXGroup", CGRect(x: 50, y: 105, width: 300, height: 50)),
            target("more", "AXButton", CGRect(x: 350, y: 110, width: 24, height: 24)),      // a real control in the row
            target("other", "AXGroup", CGRect(x: 10, y: 170, width: 380, height: 60)),
        ]
        XCTAssertEqual(TargetCollection.pruned(targets, window: window).map(\.id).sorted(), ["more", "other", "row"])
        XCTAssertEqual(TargetCollection.pruned(targets.reversed(), window: window).map(\.id).sorted(), ["more", "other", "row"])
    }

    func testEnhancedFlagRoundTripsAndDefaultsOff() {
        let profiles = ["t": AppProfile(name: "T", enhanced: true)]
        XCTAssertEqual(AppBehavior.decode(AppBehavior.encode(profiles)), profiles)
        XCTAssertFalse(AppProfile(name: "T", enhanced: true).isDefault)
        XCTAssertTrue(AppBehavior.resolve(bundleID: "t", profiles: profiles, vision: false, prescan: false).enhanced)
        XCTAssertFalse(AppBehavior.decode(#"{"x":{"name":"X"}}"#)["x"]!.enhanced)
        XCTAssertTrue(AppBehavior.decode(#"{"x":{"name":"X","enhanced":"YES"}}"#)["x"]!.enhanced)
        let spotify = AppBehavior.decode(#"{"s":{"name":"S","launchAccessibility":true}}"#)
        XCTAssertTrue(spotify["s"]!.launchAccessibility)
        XCTAssertFalse(spotify["s"]!.isDefault)
        XCTAssertTrue(AppBehavior.resolve(bundleID: "s", profiles: spotify, vision: false, prescan: false).launchAccessibility)
    }
}
