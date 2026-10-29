public enum PairingError: Error, Equatable {
    /// The code the user typed does not match the certificates exchanged: wrong code, or a man in the middle.
    case codeMismatch
    /// The code is not 6 hexadecimal characters.
    case invalidCode
}

public enum PairingCode {
    /// What a code field keeps of the text typed or pasted into it: the letter `O` read as `0`, uppercase
    /// hexadecimal characters only, at most 6. Whitespace and anything else is dropped.
    public static func sanitize(_ input: String) -> String {
        String(
            input.uppercased()
                .map { $0 == "O" ? "0" : $0 }
                .filter { $0.isASCII && $0.isHexDigit }
                .prefix(6)
        )
    }

    /// Cleans up what the user typed: removes whitespace, uppercases, reads the letter `O` as the digit `0`.
    /// Returns nil unless the result is exactly 6 hexadecimal characters.
    public static func normalize(_ input: String) -> String? {
        let cleaned = String(
            input.filter { !$0.isWhitespace }
                .uppercased()
                .map { $0 == "O" ? "0" : $0 }
        )
        guard cleaned.count == 6, cleaned.allSatisfy({ $0.isHexDigit && $0.isASCII }) else { return nil }
        return cleaned
    }
}
