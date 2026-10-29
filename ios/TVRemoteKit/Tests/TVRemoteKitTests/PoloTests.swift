import XCTest
import TVRemoteKit

final class PoloTests: XCTestCase {
    func testPairingRequestBytes() {
        XCTAssertEqual(PoloMessage.pairingRequest(clientName: "test").hex, "080210c80152110a0961747672656d6f7465120474657374")
    }

    func testOptionsBytes() {
        XCTAssertEqual(PoloMessage.options().hex, "080210c801a201080a04080310061801")
    }

    func testConfigurationBytes() {
        XCTAssertEqual(PoloMessage.configuration().hex, "080210c801f201080a04080310061001")
    }

    func testSecretBytes() {
        // field 40 (tag c2 02) wrapping field 1 = the secret
        XCTAssertEqual(PoloMessage.secret([0xde, 0xad]).hex, "080210c801c202040a02dead")
    }

    func testParseConfigurationAck() throws {
        XCTAssertEqual(try PoloReply.parse(Array(hex: "080210c801fa0100")), PoloReply(status: 200, kind: .configurationAck))
    }

    func testParsePairingRequestAck() throws {
        XCTAssertEqual(try PoloReply.parse(Array(hex: "080210c8015a00")), PoloReply(status: 200, kind: .pairingRequestAck))
    }

    func testParseOptions() throws {
        XCTAssertEqual(try PoloReply.parse(Array(hex: "080210c801a201080a04080310061801")), PoloReply(status: 200, kind: .options))
    }

    func testParseSecretAck() throws {
        XCTAssertEqual(try PoloReply.parse(Array(hex: "080210c801ca02020a00")), PoloReply(status: 200, kind: .secretAck))
    }

    func testParseBadSecretStatus() throws {
        XCTAssertEqual(try PoloReply.parse(Array(hex: "0802109203")), PoloReply(status: 402, kind: .other))
    }

    func testParseRejectsTruncatedInput() {
        XCTAssertThrowsError(try PoloReply.parse(Array(hex: "080210c801fa01")))
    }

    func testCodeNormalization() {
        XCTAssertEqual(PairingCode.normalize(" 65a1b2 "), "65A1B2")
        XCTAssertEqual(PairingCode.normalize("65 A1 B2"), "65A1B2")
        XCTAssertEqual(PairingCode.normalize("65a1o2"), "65A102")
        XCTAssertNil(PairingCode.normalize("65A1B"))
        XCTAssertNil(PairingCode.normalize("65A1BZ"))
        XCTAssertNil(PairingCode.normalize("65A1B2C"))
        XCTAssertNil(PairingCode.normalize(""))
    }
}
