import XCTest
import TVRemoteKit

final class PairingSecretTests: XCTestCase {
    private let client = RSAPublicNumbers(modulus: Array(hex: "c0ffee1122334455"), exponent: [1, 0, 1])
    private let server = RSAPublicNumbers(modulus: Array(hex: "badc0de566778899"), exponent: [1, 0, 1])

    func testSecretMatchesReferenceVector() throws {
        let secret = try PairingSecret.compute(client: client, server: server, code: "65A1B2")
        XCTAssertEqual(secret.hex, "65492b92b6551b868bee5fa9528db204d75f838705a733aeb53f40d41610d974")
    }

    func testSecretRejectsWrongCode() {
        XCTAssertThrowsError(try PairingSecret.compute(client: client, server: server, code: "66A1B2")) { error in
            XCTAssertEqual(error as? PairingError, .codeMismatch)
        }
    }

    func testSecretRejectsMalformedCode() {
        XCTAssertThrowsError(try PairingSecret.compute(client: client, server: server, code: "65A1B")) { error in
            XCTAssertEqual(error as? PairingError, .invalidCode)
        }
        XCTAssertThrowsError(try PairingSecret.compute(client: client, server: server, code: "65A1BZ")) { error in
            XCTAssertEqual(error as? PairingError, .invalidCode)
        }
    }

    func testModulusStripsLeadingZero() {
        XCTAssertEqual(RSAPublicNumbers(modulus: [0, 0xC0, 1], exponent: [0, 1, 0, 1]).modulus, [0xC0, 1])
        XCTAssertEqual(RSAPublicNumbers(modulus: [0, 0xC0, 1], exponent: [0, 1, 0, 1]).exponent, [1, 0, 1])
    }

    func testLeadingZeroBytesDoNotChangeSecret() throws {
        let padded = RSAPublicNumbers(modulus: [0, 0] + client.modulus, exponent: [0] + client.exponent)
        XCTAssertEqual(padded, client)
        XCTAssertEqual(
            try PairingSecret.compute(client: padded, server: server, code: "65A1B2"),
            try PairingSecret.compute(client: client, server: server, code: "65A1B2")
        )
    }

    func testParsesPKCS1DER() throws {
        // SEQUENCE { INTEGER 00 c0 ff ee 11 22 33 44 55 (leading zero keeps it positive), INTEGER 65537 }
        let der = Array(hex: "3010" + "0209" + "00c0ffee1122334455" + "0203" + "010001")
        let numbers = try RSAPublicNumbers(pkcs1DER: der)
        XCTAssertEqual(numbers, client)
    }

    func testRejectsGarbagePKCS1DER() {
        XCTAssertThrowsError(try RSAPublicNumbers(pkcs1DER: [0x01, 0x02]))
    }
}
