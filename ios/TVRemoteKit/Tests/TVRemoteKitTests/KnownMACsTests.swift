import XCTest
@testable import TVRemoteKit

final class KnownMACsTests: XCTestCase {
    func testReadsHostAndMACFromInfoPlist() {
        let info: [String: Any] = ["TVKnownHost": " 192.168.1.16 ", "TVKnownMAC": "00:11:22:33:44:55"]
        XCTAssertEqual(PairedTV.knownMACs(from: info), ["192.168.1.16": "00:11:22:33:44:55"])
    }

    func testEmptyWhenEitherValueIsMissingOrBlank() {
        XCTAssertEqual(PairedTV.knownMACs(from: nil), [:])
        XCTAssertEqual(PairedTV.knownMACs(from: ["TVKnownHost": "192.168.1.16"]), [:])
        XCTAssertEqual(PairedTV.knownMACs(from: ["TVKnownHost": "192.168.1.16", "TVKnownMAC": ""]), [:])
        XCTAssertEqual(PairedTV.knownMACs(from: ["TVKnownHost": "", "TVKnownMAC": "00:11:22:33:44:55"]), [:])
    }
}
