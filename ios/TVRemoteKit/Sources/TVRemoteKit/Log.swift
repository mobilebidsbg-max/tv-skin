import os

/// TVRemoteKit's loggers, under the app's bundle ID. Read them with
/// `log show --predicate 'subsystem == "com.dzafirov.tvskin.remote"'` (on a Simulator: `xcrun simctl spawn <udid> log show …`).
/// Errors and addresses are logged as public: they hold no secrets (never the pairing code or the identity).
enum Log {
    static let subsystem = "com.dzafirov.tvskin.remote"

    /// `ConnectionManager`: connecting, sessions, pairing.
    static let connection = Logger(subsystem: subsystem, category: "connection")
    /// `LiveLink`: this device's identity and Wake-on-LAN.
    static let link = Logger(subsystem: subsystem, category: "link")
    /// `TVDiscovery`: browsing for TVs and finding their addresses.
    static let discovery = Logger(subsystem: subsystem, category: "discovery")
}
