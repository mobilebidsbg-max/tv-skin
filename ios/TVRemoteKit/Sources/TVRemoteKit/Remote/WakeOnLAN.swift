import Foundation

public enum WakeOnLANError: Error, Equatable {
    /// Not six hex bytes separated by `:` or `-`.
    case invalidMAC(String)
    /// Not an IPv4 address such as `192.168.8.16`.
    case invalidHost(String)
    /// The UDP socket failed; carries `errno`.
    case socket(Int32)
}

/// Wakes a TV from standby with a magic packet, for when its remote ports are closed.
public enum WakeOnLAN {
    static let port: UInt16 = 9

    /// The magic packet: six `0xFF` bytes, then the MAC address 16 times (102 bytes).
    /// - Parameter mac: e.g. `44:0f:b4:88:a4:9b` or `44-0F-B4-88-A4-9B`.
    public static func packet(mac: String) throws -> [UInt8] {
        let parts = mac.replacingOccurrences(of: "-", with: ":").split(separator: ":", omittingEmptySubsequences: false)
        let bytes = parts.compactMap { $0.count == 2 ? UInt8($0, radix: 16) : nil }
        guard parts.count == 6, bytes.count == 6 else { throw WakeOnLANError.invalidMAC(mac) }
        return Array(repeating: 0xFF, count: 6) + Array([[UInt8]](repeating: bytes, count: 16).joined())
    }

    /// Broadcasts the magic packet to `255.255.255.255:9`.
    public static func send(mac: String) async throws {
        try send(try packet(mac: mac), to: INADDR_BROADCAST, port: port, broadcast: true)
    }

    /// Sends the magic packet straight to `host` (an IPv4 address) on port 9.
    ///
    /// Unlike a broadcast this needs no special permission on iOS, but it only reaches a sleeping TV while
    /// the network still knows which hardware address `host` belongs to.
    public static func send(mac: String, to host: String) async throws {
        try await send(mac: mac, to: host, port: port)
    }

    /// `send(mac:to:)` with the port injectable for tests.
    static func send(mac: String, to host: String, port: UInt16) async throws {
        let payload = try packet(mac: mac)
        var address = in_addr()
        guard inet_pton(AF_INET, host, &address) == 1 else { throw WakeOnLANError.invalidHost(host) }
        try send(payload, to: address.s_addr, port: port, broadcast: false)
    }

    /// Sends one UDP datagram to `address` (network byte order) and `port`.
    private static func send(_ payload: [UInt8], to address: in_addr_t, port: UInt16, broadcast: Bool) throws {
        let descriptor = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        guard descriptor >= 0 else { throw WakeOnLANError.socket(errno) }
        defer { close(descriptor) }

        if broadcast {
            var enabled: Int32 = 1
            guard setsockopt(descriptor, SOL_SOCKET, SO_BROADCAST, &enabled, socklen_t(MemoryLayout<Int32>.size)) == 0 else {
                throw WakeOnLANError.socket(errno)
            }
        }

        var socketAddress = sockaddr_in()
        socketAddress.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        socketAddress.sin_family = sa_family_t(AF_INET)
        socketAddress.sin_port = port.bigEndian
        socketAddress.sin_addr.s_addr = address
        let sent = payload.withUnsafeBytes { buffer in
            withUnsafePointer(to: &socketAddress) { pointer in
                pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    sendto(descriptor, buffer.baseAddress, buffer.count, 0, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
        }
        guard sent == payload.count else { throw WakeOnLANError.socket(errno) }
    }
}
