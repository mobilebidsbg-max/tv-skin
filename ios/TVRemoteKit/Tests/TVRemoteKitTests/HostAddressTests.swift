import XCTest
import TVRemoteKit

final class HostAddressTests: XCTestCase {
    func testDigitsAndDotsAreKept() {
        XCTAssertEqual(HostAddress.sanitize("192.168.8.16"), "192.168.8.16")
    }

    func testACommaIsReadAsADot() {
        // Decimal pads show "," where the region's decimal separator is a comma (Bulgarian, for one).
        XCTAssertEqual(HostAddress.sanitize("192,168,8,16"), "192.168.8.16")
    }

    func testOtherCharactersAreDropped() {
        XCTAssertEqual(HostAddress.sanitize(" 192.168 .8a-.16\n٣"), "192.168.8.16")
    }

    func testLengthIsCappedAtTheLongestIPv4Address() {
        XCTAssertEqual(HostAddress.sanitize("192.168.100.1234567"), "192.168.100.123")
        XCTAssertEqual(HostAddress.sanitize("255.255.255.255").count, 15)
    }
}
