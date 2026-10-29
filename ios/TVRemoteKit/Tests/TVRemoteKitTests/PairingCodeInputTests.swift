import XCTest
import TVRemoteKit

final class PairingCodeInputTests: XCTestCase {
    func testSanitizeUppercasesAndKeepsHexCharacters() {
        XCTAssertEqual(PairingCode.sanitize("65a1b2"), "65A1B2")
    }

    func testSanitizeReadsLetterOAsZero() {
        XCTAssertEqual(PairingCode.sanitize("65a1o2"), "65A102")
    }

    func testSanitizeDropsEverythingThatIsNotHex() {
        XCTAssertEqual(PairingCode.sanitize("6-5 z1\n#"), "651")
        XCTAssertEqual(PairingCode.sanitize("é٣"), "")
    }

    func testSanitizeCutsAtSixCharacters() {
        XCTAssertEqual(PairingCode.sanitize("65A1B2C3"), "65A1B2")
    }

    func testSanitizeKeepsAPartialCode() {
        XCTAssertEqual(PairingCode.sanitize("65A"), "65A")
        XCTAssertEqual(PairingCode.sanitize(""), "")
    }

    func testPastedCodeWithSpacesBecomesAValidCode() {
        XCTAssertEqual(PairingCode.normalize(PairingCode.sanitize(" 65A 1B2\n") ), "65A1B2")
    }
}
