import Foundation
import X509
import _CryptoExtras

/// This device's TLS client identity: a self-signed RSA-2048 certificate and its private key, both PEM.
/// The TV remembers the certificate after pairing, so the identity must be kept and reused.
public struct ClientIdentity: Codable, Equatable {
    public let certificatePEM: String
    public let privateKeyPEM: String

    public init(certificatePEM: String, privateKeyPEM: String) {
        self.certificatePEM = certificatePEM
        self.privateKeyPEM = privateKeyPEM
    }

    /// The common name every identity used before 2026-11-01. The TV keeps one pairing per common name, so all
    /// devices sharing it unpaired each other (TV log: "KeyStoreManager: Deleting entry for … (CN=atvremote)").
    public static let sharedLegacyCommonName = "atvremote"

    /// A common name of its own for a new identity: "atvremote-" and 8 random hex digits.
    public static func uniqueCommonName() -> String {
        String(format: "atvremote-%08x", UInt32.random(in: .min ... .max))
    }

    /// Generates a new key and a certificate valid from one day ago (clock-skew margin) to 20 years ahead.
    /// Without a `commonName`, the certificate gets a unique one (see `uniqueCommonName()`).
    public static func generate(commonName: String? = nil) throws -> ClientIdentity {
        let commonName = commonName ?? uniqueCommonName()
        let key = try _RSA.Signing.PrivateKey(keySize: .bits2048)
        let certificateKey = Certificate.PrivateKey(key)
        let name = try DistinguishedName { CommonName(commonName) }
        let now = Date()
        let certificate = try Certificate(
            version: .v3,
            serialNumber: Certificate.SerialNumber(),
            publicKey: certificateKey.publicKey,
            notValidBefore: now.addingTimeInterval(-24 * 3600),
            notValidAfter: Calendar(identifier: .gregorian).date(byAdding: .year, value: 20, to: now)
                ?? now.addingTimeInterval(20 * 365 * 24 * 3600),
            issuer: name,
            subject: name,
            signatureAlgorithm: .sha256WithRSAEncryption,
            extensions: Certificate.Extensions(),
            issuerPrivateKey: certificateKey
        )
        return ClientIdentity(
            certificatePEM: try certificate.serializeAsPEM().pemString,
            privateKeyPEM: key.pemRepresentation
        )
    }

    /// True when the certificate's subject is exactly `CN=atvremote`, the name every device used to share.
    public func usesSharedLegacyName() throws -> Bool {
        let certificate = try Certificate(pemEncoded: certificatePEM)
        return certificate.subject == (try DistinguishedName { CommonName(Self.sharedLegacyCommonName) })
    }

    /// The RSA numbers of the certificate's public key, as the pairing secret needs them.
    public func publicNumbers() throws -> RSAPublicNumbers {
        try RSAPublicNumbers(certificate: try Certificate(pemEncoded: certificatePEM))
    }
}
