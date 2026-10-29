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

    /// Generates a new key and a certificate valid from one day ago (clock-skew margin) to 20 years ahead.
    public static func generate(commonName: String = "atvremote") throws -> ClientIdentity {
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

    /// The RSA numbers of the certificate's public key, as the pairing secret needs them.
    public func publicNumbers() throws -> RSAPublicNumbers {
        try RSAPublicNumbers(certificate: try Certificate(pemEncoded: certificatePEM))
    }
}
