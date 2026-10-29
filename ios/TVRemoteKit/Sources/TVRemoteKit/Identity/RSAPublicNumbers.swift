import SwiftASN1
import X509
import _CryptoExtras

/// The modulus and public exponent of an RSA key as unsigned big-endian bytes with no leading zeros.
/// This is the form the pairing secret hashes.
public struct RSAPublicNumbers: Equatable {
    public let modulus: [UInt8]
    public let exponent: [UInt8]

    /// Strips leading zero bytes from both values (DER INTEGERs carry one to keep the sign positive).
    public init(modulus: [UInt8], exponent: [UInt8]) {
        self.modulus = Array(modulus.drop { $0 == 0 })
        self.exponent = Array(exponent.drop { $0 == 0 })
    }

    /// Parses a PKCS#1 `RSAPublicKey ::= SEQUENCE { modulus INTEGER, publicExponent INTEGER }`.
    public init(pkcs1DER: [UInt8]) throws {
        let node = try DER.parse(pkcs1DER)
        let (modulus, exponent) = try DER.sequence(node, identifier: .sequence) { nodes in
            (try ArraySlice<UInt8>(derEncoded: &nodes), try ArraySlice<UInt8>(derEncoded: &nodes))
        }
        self.init(modulus: Array(modulus), exponent: Array(exponent))
    }

    /// Reads the RSA key out of a DER certificate's SubjectPublicKeyInfo.
    /// Throws if the certificate does not parse or its key is not RSA.
    public init(certificateDER: [UInt8]) throws {
        try self.init(certificate: try X509.Certificate(derEncoded: certificateDER))
    }

    init(certificate: X509.Certificate) throws {
        guard _RSA.Signing.PublicKey(certificate.publicKey) != nil else {
            throw ASN1Error.invalidASN1Object(reason: "certificate key is not RSA")
        }
        // For RSA, X509 exposes the SubjectPublicKeyInfo BIT STRING contents, which is the PKCS#1 RSAPublicKey.
        try self.init(pkcs1DER: Array(certificate.publicKey.subjectPublicKeyInfoBytes))
    }
}
