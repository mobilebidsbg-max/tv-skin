import XCTest
import Crypto
import _CryptoExtras
import X509
import SwiftASN1
import TVRemoteKit

final class IdentityTests: XCTestCase {
    func testGeneratedIdentityIsSelfSignedRSA2048() throws {
        let id = try ClientIdentity.generate()
        let n = try id.publicNumbers()
        XCTAssertEqual(n.modulus.count, 256)
        XCTAssertEqual(n.exponent, [1, 0, 1])

        let cert = try X509.Certificate(pemEncoded: id.certificatePEM)
        XCTAssertNotNil(cert.subject.description.range(of: "^CN=atvremote-[0-9a-f]{8}$", options: .regularExpression),
                        "unexpected subject \(cert.subject.description)")
        XCTAssertEqual(cert.subject, cert.issuer, "certificate must be self-signed")
        XCTAssertEqual(cert.signatureAlgorithm, .sha256WithRSAEncryption)
        XCTAssertEqual(try RSAPublicNumbers(certificateDER: try cert.serializeAsPEM().derBytes), n)

        let now = Date()
        XCTAssertLessThan(cert.notValidBefore, now)
        XCTAssertGreaterThan(cert.notValidAfter, now.addingTimeInterval(19 * 365 * 24 * 3600))
    }

    func testPrivateKeyPEMMatchesCertificate() throws {
        let id = try ClientIdentity.generate()
        let key = try _RSA.Signing.PrivateKey(pemRepresentation: id.privateKeyPEM)
        let fromKey = try RSAPublicNumbers(pkcs1DER: Array(key.publicKey.pkcs1DERRepresentation))
        XCTAssertEqual(fromKey, try id.publicNumbers())
    }

    func testCommonNameIsConfigurable() throws {
        let id = try ClientIdentity.generate(commonName: "other")
        let cert = try X509.Certificate(pemEncoded: id.certificatePEM)
        XCTAssertEqual(cert.subject.description, "CN=other")
    }

    func testRSAPublicNumbersRejectsGarbageCertificate() {
        XCTAssertThrowsError(try RSAPublicNumbers(certificateDER: [0x30, 0x00]))
    }

    func testRSAPublicNumbersRejectsNonRSACertificate() throws {
        let key = P256.Signing.PrivateKey()
        let name = try DistinguishedName { CommonName("ec") }
        let cert = try X509.Certificate(
            version: .v3, serialNumber: .init(), publicKey: .init(key.publicKey),
            notValidBefore: Date() - 60, notValidAfter: Date() + 3600,
            issuer: name, subject: name, signatureAlgorithm: .ecdsaWithSHA256,
            extensions: .init(), issuerPrivateKey: .init(key))
        XCTAssertThrowsError(try RSAPublicNumbers(certificateDER: try cert.serializeAsPEM().derBytes))
    }

    func testFileIdentityStoreRoundTrip() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("tvremote-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = FileIdentityStore(directory: dir)

        XCTAssertNil(try store.load())
        let first = try store.loadOrCreate()
        let second = try store.loadOrCreate()
        XCTAssertEqual(first, second)
        XCTAssertEqual(try store.load(), first)
        XCTAssertTrue(FileManager.default.fileExists(atPath: dir.appendingPathComponent("identity.json").path))
    }

    func testFileIdentityStoreSaveOverwrites() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("tvremote-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = FileIdentityStore(directory: dir)
        let a = try ClientIdentity.generate()
        let b = try ClientIdentity.generate(commonName: "second")
        try store.save(a)
        try store.save(b)
        XCTAssertEqual(try store.load(), b)
    }

    // The TV keeps one pairing per certificate common name: a second client with the same name deletes the first
    // one's pairing (TV log: "KeyStoreManager: Deleting entry for atvremote-… (CN=atvremote)"). So every identity
    // needs its own name.
    func testEachGeneratedIdentityHasItsOwnCommonName() throws {
        let a = try X509.Certificate(pemEncoded: try ClientIdentity.generate().certificatePEM)
        let b = try X509.Certificate(pemEncoded: try ClientIdentity.generate().certificatePEM)
        XCTAssertNotEqual(a.subject, b.subject)
    }

    func testSharedLegacyNameIsDetected() throws {
        XCTAssertTrue(try ClientIdentity.generate(commonName: "atvremote").usesSharedLegacyName())
        XCTAssertFalse(try ClientIdentity.generate().usesSharedLegacyName())
        XCTAssertFalse(try ClientIdentity.generate(commonName: "atvremote-1").usesSharedLegacyName())
    }

    func testLoadOrCreateReplacesAnIdentityWithTheSharedLegacyName() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("tvremote-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = FileIdentityStore(directory: dir)
        let legacy = try ClientIdentity.generate(commonName: "atvremote")
        try store.save(legacy)

        let result = try store.loadOrCreateReporting()
        XCTAssertEqual(result.how, .replacedSharedName)
        XCTAssertNotEqual(result.identity, legacy)
        XCTAssertFalse(try result.identity.usesSharedLegacyName())
        XCTAssertEqual(try store.load(), result.identity, "the replacement must be saved")
        XCTAssertEqual(try store.loadOrCreateReporting().how, .loaded)
    }

    func testLoadOrCreateReportsCreatedThenLoaded() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("tvremote-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = FileIdentityStore(directory: dir)
        let created = try store.loadOrCreateReporting()
        XCTAssertEqual(created.how, .created)
        let loaded = try store.loadOrCreateReporting()
        XCTAssertEqual(loaded.how, .loaded)
        XCTAssertEqual(loaded.identity, created.identity)
    }
}
