import XCTest
@testable import SprayCanCore

final class RefreshPolicyTests: XCTestCase {
    func decide(_ trigger: RefreshTrigger = .structural, mode: NavigationMode = .elements, holding: Bool = false,
                selecting: Bool = false, typing: Bool = false, since: TimeInterval = 5) -> RefreshPolicy.Decision {
        RefreshPolicy.decide(trigger, mode: mode, holding: holding, selecting: selecting, typing: typing, sinceLastScan: since)
    }
    func testWindowChangesRefreshElementsAndScrollEvenWhileTyping() {
        XCTAssertEqual(decide(), .refresh)
        XCTAssertEqual(decide(typing: true), .refresh)
        XCTAssertEqual(decide(mode: .scroll), .refresh)
    }
    func testDragsCancelAndClicksInFlightAreLeftAlone() {
        XCTAssertEqual(decide(holding: true), .cancel)
        XCTAssertEqual(decide(holding: true, selecting: true), .cancel)
        XCTAssertEqual(decide(selecting: true), .ignore)
    }
    func testScreenBasedModesIgnoreWindowChanges() {
        XCTAssertEqual(decide(mode: .grid), .ignore)
        XCTAssertEqual(decide(mode: .freestyle), .ignore)
    }
    func testTitleChangesAreThrottledAndNeverInterruptTyping() {
        XCTAssertEqual(decide(.title), .refresh)
        XCTAssertEqual(decide(.title, since: 0.2), .ignore)
        XCTAssertEqual(decide(.title, typing: true), .ignore)
        XCTAssertEqual(decide(.structural, since: 0.2), .refresh)
    }
}

final class OCRLanguagesTests: XCTestCase {
    let supported = ["en-US", "fr-FR", "de-DE", "es-ES", "ru-RU", "zh-Hans", "zh-Hant", "ja-JP", "ko-KR", "th-TH"]

    func testCombinableLanguagesShareOnePassInOrder() {
        XCTAssertEqual(OCRLanguages.passes(selected: ["es-ES", "en-US", "ru-RU"], supported: supported), [["es-ES", "en-US", "ru-RU"]])
    }
    func testEachOtherScriptGetsItsOwnPassWithEnglish() {
        XCTAssertEqual(OCRLanguages.passes(selected: ["en-US", "zh-Hans", "ja-JP", "ko-KR"], supported: supported),
                       [["en-US"], ["zh-Hans", "en-US"], ["ja-JP", "en-US"], ["ko-KR", "en-US"]])
        XCTAssertEqual(OCRLanguages.passes(selected: ["ja-JP", "fr-FR"], supported: supported), [["ja-JP", "en-US"], ["fr-FR"]])
    }
    func testUnsupportedDuplicateAndEmptySelectionsFallBackToEnglish() {
        XCTAssertEqual(OCRLanguages.normalized(["xx-XX", "ko-KR", "ko-KR"], supported: supported), ["ko-KR"])
        XCTAssertEqual(OCRLanguages.passes(selected: [], supported: supported), [["en-US"]])
        XCTAssertEqual(OCRLanguages.passes(selected: ["xx-XX"], supported: supported), [["en-US"]])
    }
    func testDefaultsFollowPreferredLanguagesAndScripts() {
        XCTAssertEqual(OCRLanguages.defaultSelection(preferred: ["zh-Hant-TW", "ja-JP", "en-GB"], supported: supported), ["zh-Hant", "ja-JP", "en-US"])
        XCTAssertEqual(OCRLanguages.defaultSelection(preferred: ["zh-Hans-CN"], supported: supported), ["zh-Hans", "en-US"])
        XCTAssertEqual(OCRLanguages.defaultSelection(preferred: ["de-AT", "fi-FI"], supported: supported), ["de-DE", "en-US"])
        XCTAssertEqual(OCRLanguages.defaultSelection(preferred: [], supported: supported), ["en-US"])
    }
    func testMergeKeepsTheMostConfidentReadingOfEachRegion() {
        let latin = OCRText(frame: CGRect(x: 0, y: 0, width: 100, height: 20), text: "Setlings", confidence: 0.7)
        let cjk = OCRText(frame: CGRect(x: 2, y: 0, width: 98, height: 20), text: "設定", confidence: 0.95)
        let other = OCRText(frame: CGRect(x: 0, y: 40, width: 60, height: 20), text: "Open", confidence: 0.9)
        XCTAssertEqual(OCRLanguages.merge([[latin, other], [cjk]]), [cjk, other])
        XCTAssertEqual(OCRLanguages.merge([[latin], []]), [latin])
    }
}
