import Crypto

public enum PairingSecret {
    /// The proof the TV expects after the user types the code:
    /// SHA-256(client.modulus ‖ client.exponent ‖ server.modulus ‖ server.exponent ‖ code bytes 1...2).
    /// The first code byte must equal the first digest byte; that is how the TV's code is checked
    /// against the two certificates without ever sending the code itself.
    /// - Throws: `PairingError.invalidCode` for a malformed code, `PairingError.codeMismatch` for a wrong one.
    public static func compute(client: RSAPublicNumbers, server: RSAPublicNumbers, code: String) throws -> [UInt8] {
        guard let normalized = PairingCode.normalize(code) else { throw PairingError.invalidCode }
        let code = hexBytes(normalized)

        var hash = SHA256()
        hash.update(data: client.modulus)
        hash.update(data: client.exponent)
        hash.update(data: server.modulus)
        hash.update(data: server.exponent)
        hash.update(data: code[1...])
        let digest = Array(hash.finalize())

        guard digest[0] == code[0] else { throw PairingError.codeMismatch }
        return digest
    }

    /// Decodes an already validated string of hex pairs.
    private static func hexBytes(_ hex: String) -> [UInt8] {
        var bytes: [UInt8] = []
        var index = hex.startIndex
        while index < hex.endIndex {
            let next = hex.index(index, offsetBy: 2)
            bytes.append(UInt8(hex[index..<next], radix: 16)!)
            index = next
        }
        return bytes
    }
}
