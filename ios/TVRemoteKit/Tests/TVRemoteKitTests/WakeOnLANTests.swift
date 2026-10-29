import XCTest
import TVRemoteKit

final class WakeOnLANTests: XCTestCase {
    func testWakePacket() throws {
        let p = try WakeOnLAN.packet(mac: "44:0f:b4:88:a4:9b")
        XCTAssertEqual(p.count, 102)
        XCTAssertEqual(Array(p[0..<6]), Array(repeating: 0xFF, count: 6))
        XCTAssertEqual(Array(p[96..<102]), [0x44, 0x0f, 0xb4, 0x88, 0xa4, 0x9b])
    }

    func testWakePacketRejectsBadMac() { XCTAssertThrowsError(try WakeOnLAN.packet(mac: "44:0f:b4")) }

    func testWakePacketRepeatsTheMacSixteenTimes() throws {
        let p = try WakeOnLAN.packet(mac: "44-0F-B4-88-A4-9B")
        for copy in 0..<16 {
            let start = 6 + copy * 6
            XCTAssertEqual(Array(p[start..<start + 6]), [0x44, 0x0f, 0xb4, 0x88, 0xa4, 0x9b])
        }
    }

    func testWakePacketRejectsNonHexMac() {
        XCTAssertThrowsError(try WakeOnLAN.packet(mac: "44:0f:b4:88:a4:zz"))
        XCTAssertThrowsError(try WakeOnLAN.packet(mac: "44:0f:b4:88:a4:9b:00"))
        XCTAssertThrowsError(try WakeOnLAN.packet(mac: "440:f:b4:88:a4:9b"))
    }
}
