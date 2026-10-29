import Foundation

public enum WakeOnLANError: Error, Equatable {
    /// Not six hex bytes separated by `:` or `-`.
    case invalidMAC(String)
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
        let payload = try packet(mac: mac)
        let descriptor = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        guard descriptor >= 0 else { throw WakeOnLANError.socket(errno) }
        defer { close(descriptor) }

        var enabled: Int32 = 1
        guard setsockopt(descriptor, SOL_SOCKET, SO_BROADCAST, &enabled, socklen_t(MemoryLayout<Int32>.size)) == 0 else {
            throw WakeOnLANError.socket(errno)
        }

        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = port.bigEndian
        address.sin_addr.s_addr = INADDR_BROADCAST
        let sent = payload.withUnsafeBytes { buffer in
            withUnsafePointer(to: &address) { pointer in
                pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    sendto(descriptor, buffer.baseAddress, buffer.count, 0, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
        }
        guard sent == payload.count else { throw WakeOnLANError.socket(errno) }
    }
}
