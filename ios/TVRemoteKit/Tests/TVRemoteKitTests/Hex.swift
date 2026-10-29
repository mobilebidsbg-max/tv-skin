extension Array where Element == UInt8 {
    /// Builds bytes from a lowercase/uppercase hex string such as "0a0b". Test helper: traps on bad input.
    init(hex: String) {
        precondition(hex.count % 2 == 0, "odd-length hex string")
        var out: [UInt8] = []
        out.reserveCapacity(hex.count / 2)
        var index = hex.startIndex
        while index < hex.endIndex {
            let next = hex.index(index, offsetBy: 2)
            guard let byte = UInt8(hex[index..<next], radix: 16) else {
                preconditionFailure("invalid hex pair \(hex[index..<next])")
            }
            out.append(byte)
            index = next
        }
        self = out
    }

    /// Lowercase hex, two digits per byte.
    var hex: String {
        map { byte in
            let digits = String(byte, radix: 16)
            return digits.count == 1 ? "0" + digits : digits
        }.joined()
    }
}
