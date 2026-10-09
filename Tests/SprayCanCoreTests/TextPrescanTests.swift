import XCTest
@testable import SprayCanCore

final class TextPrescanTests: XCTestCase {
    func testPrescanNeedsEveryGuard() {
        func allowed(enabled: Bool = true, vision: Bool = true, screenRecording: Bool = true, onPower: Bool = true,
                     lowPower: Bool = false, thermal: Bool = false, active: Bool = false, own: Bool = false) -> Bool {
            TextPrescan.allowed(enabled: enabled, vision: vision, screenRecording: screenRecording, onPower: onPower,
                                lowPower: lowPower, thermalSerious: thermal, sessionActive: active, ownApp: own)
        }
        XCTAssertTrue(allowed())
        XCTAssertFalse(allowed(enabled: false))
        XCTAssertFalse(allowed(vision: false))
        XCTAssertFalse(allowed(screenRecording: false))
        XCTAssertFalse(allowed(onPower: false))
        XCTAssertFalse(allowed(lowPower: true))
        XCTAssertFalse(allowed(thermal: true))
        XCTAssertFalse(allowed(active: true))
        XCTAssertFalse(allowed(own: true))
    }

    private func image(shift: Int = 0) -> [UInt8] {
        // Text-like stripes: dark rows every few pixels on a light background.
        (0..<(TextFingerprint.width * TextFingerprint.height)).map { index in
            let row = index / TextFingerprint.width
            return (row + shift) % 4 == 0 ? 40 : 230
        }
    }

    func testFingerprintToleratesCaretButNotScroll() {
        let base = TextFingerprint(pixels: image())
        XCTAssertTrue(base.matches(base))
        var caret = image(); caret[100] = 0; caret[101] = 0
        XCTAssertFalse(caret == image())
        XCTAssertTrue(base.matches(TextFingerprint(pixels: caret)))
        XCTAssertFalse(base.matches(TextFingerprint(pixels: image(shift: 1))))
        XCTAssertFalse(base.matches(TextFingerprint(pixels: [])))
        XCTAssertFalse(base.matches(TextFingerprint(pixels: Array(image().prefix(10)))))
    }

    func testCacheReuseNeedsSameWindowLanguagesAndAge() {
        let frame = CGRect(x: 10, y: 20, width: 800, height: 600)
        let cache = TextCache(pid: 42, frame: frame, languages: ["en-US"], fingerprint: TextFingerprint(pixels: image()),
                              created: 100, targets: [Target(id: "text-1-0", frame: .zero, source: .text, title: "Hi")])
        XCTAssertTrue(cache.reusable(pid: 42, frame: frame.offsetBy(dx: 0.2, dy: 0), languages: ["en-US"], now: 150))
        XCTAssertFalse(cache.reusable(pid: 43, frame: frame, languages: ["en-US"], now: 150))
        XCTAssertFalse(cache.reusable(pid: 42, frame: frame.offsetBy(dx: 30, dy: 0), languages: ["en-US"], now: 150))
        XCTAssertFalse(cache.reusable(pid: 42, frame: frame, languages: ["en-US", "ja-JP"], now: 150))
        XCTAssertFalse(cache.reusable(pid: 42, frame: frame, languages: ["en-US"], now: 100 + TextPrescan.maxAge + 1))
        XCTAssertFalse(cache.reusable(pid: 42, frame: frame, languages: ["en-US"], now: 50))
    }
}
