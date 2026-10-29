import Network
import XCTest
@testable import TVRemoteKit

final class TVDiscoveryTests: XCTestCase {
    func testPolicyDeniedIsTheDNSServiceError() {
        XCTAssertTrue(TVDiscovery.isPolicyDenied(.dns(-65570)))
    }

    func testOtherErrorsAreNotPolicyDenied() {
        XCTAssertFalse(TVDiscovery.isPolicyDenied(.dns(-65537)))
        XCTAssertFalse(TVDiscovery.isPolicyDenied(.posix(.ECONNREFUSED)))
    }

    func testHostStringOfAnIPv4Address() throws {
        let address = try XCTUnwrap(IPv4Address("192.168.8.16"))
        XCTAssertEqual(TVDiscovery.hostString(.ipv4(address)), "192.168.8.16")
    }

    func testHostStringOfAName() {
        XCTAssertEqual(TVDiscovery.hostString(.name("tv.local", nil)), "tv.local")
    }

    func testListHoldsResolvedTVsSortedByName() {
        let list = TVDiscovery.list(from: [
            "Smart TV Pro": "192.168.8.16",
            "Bedroom": "192.168.8.20",
            "Pending": nil,
        ])
        XCTAssertEqual(list, [
            DiscoveredTV(id: "Bedroom", name: "Bedroom", host: "192.168.8.20"),
            DiscoveredTV(id: "Smart TV Pro", name: "Smart TV Pro", host: "192.168.8.16"),
        ])
    }

    func testStopEndsTheResultsStream() async {
        let discovery = TVDiscovery()
        discovery.stop()
        var count = 0
        for await _ in discovery.results { count += 1 }
        XCTAssertEqual(count, 0)
    }
}
