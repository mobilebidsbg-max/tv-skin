import Foundation
import XCTest
@testable import TVRemoteKit

final class WakeOnLANTests: XCTestCase {
    func testWakePacket() throws {
        let p = try WakeOnLAN.packet(mac: "00:11:22:33:44:55")
        XCTAssertEqual(p.count, 102)
        XCTAssertEqual(Array(p[0..<6]), Array(repeating: 0xFF, count: 6))
        XCTAssertEqual(Array(p[96..<102]), [0x00, 0x11, 0x22, 0x33, 0x44, 0x55])
    }

    func testWakePacketRejectsBadMac() { XCTAssertThrowsError(try WakeOnLAN.packet(mac: "00:11:22")) }

    func testWakePacketRepeatsTheMacSixteenTimes() throws {
        let p = try WakeOnLAN.packet(mac: "00-11-22-33-44-55")
        for copy in 0..<16 {
            let start = 6 + copy * 6
            XCTAssertEqual(Array(p[start..<start + 6]), [0x00, 0x11, 0x22, 0x33, 0x44, 0x55])
        }
    }

    func testWakePacketRejectsNonHexMac() {
        XCTAssertThrowsError(try WakeOnLAN.packet(mac: "00:11:22:33:44:zz"))
        XCTAssertThrowsError(try WakeOnLAN.packet(mac: "00:11:22:33:44:55:00"))
        XCTAssertThrowsError(try WakeOnLAN.packet(mac: "001:1:22:33:44:55"))
    }

    func testUnicastSendsThePacketToTheHost() async throws {
        let receiver = try UDPReceiver()
        defer { receiver.close() }

        try await WakeOnLAN.send(mac: "00:11:22:33:44:55", to: "127.0.0.1", port: receiver.port)

        XCTAssertEqual(try receiver.receive(), try WakeOnLAN.packet(mac: "00:11:22:33:44:55"))
    }

    /// The app's wake: the packet goes out three times, about 100 ms apart. (A made-up MAC, and no broadcast, so
    /// nothing on the real network can wake.)
    func testLiveWakeSendsThePacketThreeTimesAbout100msApart() async throws {
        let receiver = try UDPReceiver()
        defer { receiver.close() }
        let mac = "02:00:00:00:00:01"
        let start = Date()

        try await LiveLink.wake(mac: mac, host: "127.0.0.1", port: receiver.port, broadcast: false)

        let elapsed = Date().timeIntervalSince(start)
        let packet = try WakeOnLAN.packet(mac: mac)
        XCTAssertEqual(try receiver.receive(), packet)
        XCTAssertEqual(try receiver.receive(), packet)
        XCTAssertEqual(try receiver.receive(), packet)
        XCTAssertGreaterThanOrEqual(elapsed, 0.19)
        XCTAssertLessThan(elapsed, 1)
    }

    func testLiveWakeThrowsTheUnicastErrorAfterTryingEachTime() async {
        let start = Date()
        do {
            try await LiveLink.wake(mac: "02:00:00:00:00:01", host: "tv.local", port: 9, broadcast: false)
            XCTFail("expected invalidHost")
        } catch {
            XCTAssertEqual(error as? WakeOnLANError, .invalidHost("tv.local"))
        }
        XCTAssertGreaterThanOrEqual(Date().timeIntervalSince(start), 0.19)
    }

    func testUnicastRejectsAHostThatIsNotAnIPv4Address() async {
        do {
            try await WakeOnLAN.send(mac: "00:11:22:33:44:55", to: "tv.local")
            XCTFail("expected invalidHost")
        } catch {
            XCTAssertEqual(error as? WakeOnLANError, .invalidHost("tv.local"))
        }
    }
}

/// A UDP socket on 127.0.0.1 at a free port that waits up to 2 s for one datagram.
private final class UDPReceiver {
    let port: UInt16
    private let descriptor: Int32

    init() throws {
        let descriptor = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        guard descriptor >= 0 else { throw WakeOnLANError.socket(errno) }
        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_addr.s_addr = inet_addr("127.0.0.1")
        var length = socklen_t(MemoryLayout<sockaddr_in>.size)
        let bound = withUnsafeMutablePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(descriptor, $0, length) == 0 && getsockname(descriptor, $0, &length) == 0
            }
        }
        guard bound else {
            let error = errno
            Darwin.close(descriptor)
            throw WakeOnLANError.socket(error)
        }
        self.descriptor = descriptor
        port = UInt16(bigEndian: address.sin_port)
        var timeout = timeval(tv_sec: 2, tv_usec: 0)
        setsockopt(descriptor, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
    }

    func receive() throws -> [UInt8] {
        var buffer = [UInt8](repeating: 0, count: 512)
        let count = recv(descriptor, &buffer, buffer.count, 0)
        guard count >= 0 else { throw WakeOnLANError.socket(errno) }
        return Array(buffer[..<count])
    }

    func close() {
        Darwin.close(descriptor)
    }
}
