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
        let address = try XCTUnwrap(IPv4Address("192.168.1.16"))
        XCTAssertEqual(TVDiscovery.hostString(.ipv4(address)), "192.168.1.16")
    }

    func testHostStringOfAName() {
        XCTAssertEqual(TVDiscovery.hostString(.name("tv.local", nil)), "tv.local")
    }

    func testListHoldsResolvedTVsSortedByName() {
        let list = TVDiscovery.list(from: [
            "Smart TV Pro": "192.168.1.16",
            "Bedroom": "192.168.1.20",
            "Pending": nil,
        ])
        XCTAssertEqual(list, [
            DiscoveredTV(id: "Bedroom", name: "Bedroom", host: "192.168.1.20"),
            DiscoveredTV(id: "Smart TV Pro", name: "Smart TV Pro", host: "192.168.1.16"),
        ])
    }

    func testEveryAttemptButTheLastRequiresIPv4() {
        let last = TVDiscovery.maxAttempts - 1
        for attempt in 0..<last {
            XCTAssertTrue(TVDiscovery.ipv4Only(attempt: attempt), "attempt \(attempt)")
        }
        XCTAssertFalse(TVDiscovery.ipv4Only(attempt: last))
    }

    func testAnIPv4AddressIsAcceptedOnEveryAttempt() throws {
        let host = NWEndpoint.Host.ipv4(try XCTUnwrap(IPv4Address("192.168.1.16")))
        for attempt in 0..<TVDiscovery.maxAttempts {
            XCTAssertTrue(TVDiscovery.accepts(host, attempt: attempt), "attempt \(attempt)")
        }
    }

    func testOtherAddressesAreIgnoredUntilTheLastAttempt() throws {
        let hosts: [NWEndpoint.Host] = [
            .ipv6(try XCTUnwrap(IPv6Address("fe80::1"))),
            .name("tv.local", nil),
        ]
        let last = TVDiscovery.maxAttempts - 1
        for host in hosts {
            for attempt in 0..<last {
                XCTAssertFalse(TVDiscovery.accepts(host, attempt: attempt), "\(host) attempt \(attempt)")
            }
            XCTAssertTrue(TVDiscovery.accepts(host, attempt: last), "\(host)")
        }
    }

    func testStopEndsTheResultsStream() async {
        let discovery = TVDiscovery()
        discovery.stop()
        var count = 0
        for await _ in discovery.results { count += 1 }
        XCTAssertEqual(count, 0)
    }
}
