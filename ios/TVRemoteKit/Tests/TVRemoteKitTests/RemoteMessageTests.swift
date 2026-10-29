import XCTest
import TVRemoteKit

final class RemoteMessageTests: XCTestCase {
    // MARK: - Outbound (golden bytes from the brief)

    func testKeyInjectBytes() { XCTAssertEqual(RemoteOutbound.key(.dpadUp, .short).hex, "520408131003") }

    func testConfigureReplyBytes() {
        XCTAssertEqual(
            RemoteOutbound.configureReply(features: 615).hex,
            "0a1c08e704121718012201312a0961747672656d6f74653205312e302e30"
        )
    }

    func testSetActiveReplyBytes() { XCTAssertEqual(RemoteOutbound.setActiveReply(features: 615).hex, "120308e704") }

    func testAppLinkBytes() {
        XCTAssertEqual(
            RemoteOutbound.appLink("https://www.youtube.com").hex,
            "d205190a1768747470733a2f2f7777772e796f75747562652e636f6d"
        )
    }

    func testTextBytes() {
        XCTAssertEqual(
            RemoteOutbound.text("hello", imeCounter: 4, fieldCounter: 7).hex,
            "aa0115080410071a0f0801120b080410041a0568656c6c6f"
        )
    }

    // MARK: - Outbound (additional)

    func testPingResponseBytes() { XCTAssertEqual(RemoteOutbound.pingResponse(42).hex, "4a02082a") }

    func testLongPressStartBytes() { XCTAssertEqual(RemoteOutbound.key(.dpadCenter, .startLong).hex, "520408171001") }

    // MARK: - Inbound (from the brief)

    func testParsePing() throws { XCTAssertEqual(try RemoteInbound.parse(Array(hex: "4204082a1000")), .ping(val1: 42)) }

    func testParseStart() throws { XCTAssertEqual(try RemoteInbound.parse(Array(hex: "c202020801")), .start(isOn: true)) }

    func testParseVolume() throws {
        XCTAssertEqual(
            try RemoteInbound.parse(Array(hex: "92030b1a0354434c3064380c4000")),
            .volume(level: 12, max: 100, muted: false)
        )
    }

    // MARK: - Inbound (additional)

    func testParseConfigure() throws {
        XCTAssertEqual(try RemoteInbound.parse(Array(hex: "0a0a08ee0412051801220131")), .configure(code1: 622))
    }

    func testParseEmptySetActive() throws { XCTAssertEqual(try RemoteInbound.parse(Array(hex: "1200")), .setActive) }

    /// proto3 leaves `started = false` off the wire.
    func testParseEmptyStartIsOff() throws { XCTAssertEqual(try RemoteInbound.parse(Array(hex: "c20200")), .start(isOn: false)) }

    func testParseImeBatchEdit() throws {
        XCTAssertEqual(try RemoteInbound.parse(Array(hex: "aa010408041007")), .imeField(imeCounter: 4, fieldCounter: 7))
    }

    func testParseCurrentApp() throws {
        XCTAssertEqual(
            try RemoteInbound.parse(Array(hex: "a201150a136211636f6d2e6e6574666c69782e6e696e6a61")),
            .currentApp("com.netflix.ninja")
        )
    }

    func testParseError() throws { XCTAssertEqual(try RemoteInbound.parse(Array(hex: "1a020801")), .error) }

    func testParseUnknownMessage() throws { XCTAssertEqual(try RemoteInbound.parse(Array(hex: "9a0300")), .unknown) }

    func testParseTruncatedMessageThrows() {
        XCTAssertThrowsError(try RemoteInbound.parse(Array(hex: "c20202")))
    }

    // MARK: - Key names for the CLI

    func testKeyNames() {
        XCTAssertEqual(KeyCode(name: "UP"), .dpadUp)
        XCTAssertEqual(KeyCode(name: "down"), .dpadDown)
        XCTAssertEqual(KeyCode(name: "LEFT"), .dpadLeft)
        XCTAssertEqual(KeyCode(name: "RIGHT"), .dpadRight)
        XCTAssertEqual(KeyCode(name: "OK"), .dpadCenter)
        XCTAssertEqual(KeyCode(name: "BACK"), .back)
        XCTAssertEqual(KeyCode(name: "HOME"), .home)
        XCTAssertEqual(KeyCode(name: "PLAY_PAUSE"), .playPause)
        XCTAssertEqual(KeyCode(name: "volume-up"), .volumeUp)
        XCTAssertEqual(KeyCode(name: "HDMI1"), .hdmi1)
        XCTAssertEqual(KeyCode(name: "ALL_APPS"), .allApps)
        XCTAssertNil(KeyCode(name: "TELEPORT"))
    }

    func testEveryKeyHasAUniqueName() {
        let names = KeyCode.allCases.map(\.name)
        XCTAssertEqual(Set(names).count, KeyCode.allCases.count)
        for key in KeyCode.allCases {
            XCTAssertEqual(KeyCode(name: key.name), key)
        }
    }

    // MARK: - App shortcuts

    func testAppShortcutsAreTheInstalledAppsInOrder() {
        XCTAssertEqual(
            AppShortcut.all.map(\.name),
            ["YouTube", "Netflix", "Prime Video", "Apple TV", "Disney+", "YouTube Music", "Home", "All apps"]
        )
        XCTAssertEqual(Set(AppShortcut.all.map(\.id)).count, 8)
        for app in AppShortcut.all {
            XCTAssertTrue((app.link == nil) != (app.key == nil), "\(app.name) needs exactly one of link or key")
        }
        XCTAssertEqual(AppShortcut.all[6].key, .home)
        XCTAssertEqual(AppShortcut.all[7].key, .allApps)
    }
}
