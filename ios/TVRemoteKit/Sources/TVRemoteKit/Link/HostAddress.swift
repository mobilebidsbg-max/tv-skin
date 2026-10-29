/// Rules for the IP address a user types.
public enum HostAddress {
    /// The longest IPv4 address as text: `255.255.255.255`.
    private static let maxLength = 15

    /// What an address field keeps of the typed text: digits and dots. A comma counts as a dot, because decimal
    /// keypads show the region's decimal separator, which in many regions (Bulgaria among them) is a comma.
    public static func sanitize(_ typed: String) -> String {
        String(
            typed
                .map { $0 == "," ? "." : $0 }
                .filter { $0.isASCII && ($0.isNumber || $0 == ".") }
                .prefix(maxLength)
        )
    }
}
