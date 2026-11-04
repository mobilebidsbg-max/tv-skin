import XCTest
@testable import TVRemoteKit

private let livingRoom = DiscoveredTV(id: "Living room", name: "Living room", host: "192.168.1.16")

final class TypedAddressTests: XCTestCase {
    func testATypedAddressTakesTheNameDiscoveryFoundThere() {
        let found = [DiscoveredTV(id: "A1 Smart box", name: "A1 Smart box", host: "192.168.1.7"), livingRoom]

        XCTAssertEqual(
            DiscoveredTV.typed("192.168.1.16", among: found),
            DiscoveredTV(id: "192.168.1.16", name: "Living room", host: "192.168.1.16")
        )
    }

    func testATypedAddressDiscoveryHasNotFoundIsCalledTV() {
        XCTAssertEqual(
            DiscoveredTV.typed("192.168.1.20", among: [livingRoom]),
            DiscoveredTV(id: "192.168.1.20", name: "TV", host: "192.168.1.20")
        )
        XCTAssertEqual(DiscoveredTV.typed("192.168.1.20", among: []).name, "TV")
    }
}
