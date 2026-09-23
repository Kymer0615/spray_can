import XCTest
@testable import SprayCanCore

final class AppearanceTests: XCTestCase {
    func testColorValidationAndDefaults() {
        for role in AppearanceColor.allCases {
            XCTAssertEqual(role.validated(nil), role.defaultHex)
            for invalid in ["", "#123456", "12345", "1234567", "GG0011", "１２３４５６"] {
                XCTAssertEqual(role.validated(invalid), role.defaultHex)
            }
            XCTAssertEqual(role.validated("abcdef"), "ABCDEF")
            XCTAssertEqual(role.validated("000000"), "000000")
            XCTAssertEqual(role.validated("FFFFFF"), "FFFFFF")
        }
    }
}
