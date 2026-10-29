import Foundation
import XCTest
@testable import TVRemoteKit

private let knownTV = PairedTV(host: "192.168.8.16", name: "TCL Smart TV Pro", mac: "44:0f:b4:88:a4:9b")

/// `ConnectionManager` against fakes: nothing touches the network, and backoff sleeps are recorded instead of waited.
/// Where a test must know the retry loop has finished, it waits for `connectTask` (internal) to end.
@MainActor
final class ConnectionManagerTests: XCTestCase {
    private var link: FakeLink!
    private var store: FakeStore!
    private var clock: FakeClock!

    private func makeManager(tv: PairedTV? = knownTV) -> ConnectionManager {
        link = FakeLink()
        store = FakeStore(tv)
        clock = FakeClock()
        let clock = clock!
        return ConnectionManager(link: link, store: store, sleep: { await clock.sleep($0) })
    }

    /// An active manager whose session to the known TV is up, and that session.
    private func makeConnectedManager() async throws -> (ConnectionManager, FakeChannel) {
        let manager = makeManager()
        manager.appBecameActive()
        await waitUntil { manager.state == .connected(tvOn: true) }
        return (manager, try XCTUnwrap(link.channels.first))
    }

    // MARK: - Connecting and retrying

    func testConnectsAndReportsTvOn() async {
        let manager = makeManager()
        XCTAssertEqual(manager.tv, knownTV)

        manager.appBecameActive()
        XCTAssertEqual(manager.state, .connecting)

        await waitUntil { manager.state == .connected(tvOn: true) }
        XCTAssertEqual(link.openedHosts, ["192.168.8.16"])
    }

    func testUnreachableRetriesWithBackoff() async {
        let manager = makeManager()
        link.openResults = [.failure(.unreachable), .failure(.unreachable)]

        manager.appBecameActive()

        await waitUntil { manager.state == .connected(tvOn: true) }
        XCTAssertEqual(clock.delays, [1, 2])
        XCTAssertEqual(link.openedHosts.count, 3)
    }

    func testEveryOtherOpenFailureBacksOffUpToTenSeconds() async {
        let manager = makeManager()
        // `.closed` can come out of a failed connect too; only .notPaired and .localNetworkDenied stop the retries.
        let failures: [TVLinkError] = [.unreachable, .closed, .timeout, .protocolError("bad frame"), .unreachable, .unreachable]
        link.openResults = failures.map { .failure($0) }

        manager.appBecameActive()

        await waitUntil { manager.state == .connected(tvOn: true) }
        XCTAssertEqual(clock.delays, [1, 2, 4, 8, 10, 10])
        XCTAssertEqual(link.openedHosts.count, 7)
    }

    func testNotPairedGoesToNeedsPairingWithoutRetry() async {
        let manager = makeManager()
        link.openResults = [.failure(.notPaired)]

        manager.appBecameActive()
        await waitForEnd(of: manager.connectTask)

        XCTAssertEqual(manager.state, .needsPairing)
        XCTAssertEqual(link.openedHosts.count, 1)
        XCTAssertEqual(clock.delays, [])

        // Coming back to the app does not retry either: only pairing helps.
        manager.appWentBackground()
        manager.appBecameActive()
        XCTAssertNil(manager.connectTask)
        XCTAssertEqual(manager.state, .needsPairing)
        XCTAssertEqual(link.openedHosts.count, 1)
    }

    func testBackgroundThenActiveReconnectsExactlyOnce() async throws {
        let (manager, first) = try await makeConnectedManager()

        manager.appWentBackground()
        XCTAssertTrue(first.closed)
        XCTAssertEqual(manager.state, .connecting)

        link.holdsOpens = true
        manager.appBecameActive()
        manager.appBecameActive()
        await waitUntil { self.link.openedHosts.count == 2 }
        // Again while that attempt is still under way.
        manager.appBecameActive()
        link.releaseOpens()
        await waitUntil { manager.state == .connected(tvOn: true) }
        await settle()

        XCTAssertEqual(link.openedHosts.count, 2)
        // Already connected: one more activation opens nothing.
        manager.appBecameActive()
        XCTAssertNil(manager.connectTask)
        XCTAssertEqual(link.openedHosts.count, 2)
    }

    func testBackgroundStopsRetrying() async {
        let manager = makeManager()
        link.openResults = [.failure(.unreachable)]
        clock.holds = true
        manager.appBecameActive()
        await waitUntil { self.clock.delays == [1] }
        let retries = manager.connectTask

        manager.appWentBackground()
        await waitForEnd(of: retries)

        XCTAssertEqual(link.openedHosts.count, 1)
        XCTAssertEqual(manager.state, .connecting)
    }

    func testClosedSessionReconnectsAfterOneSecond() async throws {
        let (manager, first) = try await makeConnectedManager()
        first.emit(.volume(level: 12, max: 100, muted: false))
        await waitUntil { manager.volume != nil }

        first.emit(.closed(.timeout))

        await waitUntil { self.link.channels.count == 2 && manager.state == .connected(tvOn: true) }
        XCTAssertEqual(clock.delays, [1])
        XCTAssertNil(manager.volume)
    }

    func testLocalNetworkDeniedStopsRetrying() async {
        let manager = makeManager()
        link.openResults = [.failure(.unreachable)]
        clock.holds = true
        manager.appBecameActive()
        await waitUntil { manager.state == .unreachable && self.clock.delays == [1] }
        let retries = manager.connectTask

        manager.localNetworkDenied()
        XCTAssertEqual(manager.state, .localNetworkDenied)
        await waitForEnd(of: retries)

        XCTAssertEqual(link.openedHosts.count, 1)
        XCTAssertEqual(manager.state, .localNetworkDenied)
    }

    func testLocalNetworkDeniedOnOpenWaitsUntilTheAppIsActiveAgain() async {
        let manager = makeManager()
        link.openResults = [.failure(.localNetworkDenied)]

        manager.appBecameActive()
        await waitForEnd(of: manager.connectTask)
        XCTAssertEqual(manager.state, .localNetworkDenied)
        XCTAssertEqual(link.openedHosts.count, 1)
        XCTAssertEqual(clock.delays, [])

        // Back from Settings with Local Network allowed.
        manager.appWentBackground()
        manager.appBecameActive()
        await waitUntil { manager.state == .connected(tvOn: true) }
        XCTAssertEqual(link.openedHosts.count, 2)
    }

    // MARK: - Session events

    func testEventsUpdateStateVolumeAndTyping() async throws {
        let manager = makeManager()
        link.openResults = [.success(FakeChannel(isOn: false))]
        manager.appBecameActive()
        await waitUntil { manager.state == .connected(tvOn: false) }
        let channel = try XCTUnwrap(link.channels.first)
        XCTAssertNil(manager.volume)
        XCTAssertFalse(manager.canType)

        channel.emit(.power(isOn: true))
        channel.emit(.volume(level: 12, max: 100, muted: true))
        channel.emit(.textField(available: true))
        channel.emit(.currentApp("com.google.android.youtube.tv"))

        await waitUntil { manager.canType }
        XCTAssertEqual(manager.state, .connected(tvOn: true))
        XCTAssertEqual(manager.volume, VolumeInfo(level: 12, max: 100, muted: true))
    }

    // MARK: - Commands

    func testPerformMapsCommandsToKeys() async throws {
        let (manager, channel) = try await makeConnectedManager()

        manager.perform(.longStart(.dpadCenter))
        manager.perform(.longEnd(.dpadCenter))
        manager.perform(.key(.dpadUp))
        manager.press(.home)

        XCTAssertEqual(channel.presses, [
            FakeChannel.Press(key: .dpadCenter, direction: .startLong),
            FakeChannel.Press(key: .dpadCenter, direction: .endLong),
            FakeChannel.Press(key: .dpadUp, direction: .short),
            FakeChannel.Press(key: .home, direction: .short),
        ])
    }

    func testOpenLaunchesTheLinkOrPressesTheKey() async throws {
        let (manager, channel) = try await makeConnectedManager()
        let youTube = AppShortcut(id: "youtube", name: "YouTube", link: "https://www.youtube.com", tint: "#FF0033")
        let home = AppShortcut(id: "home", name: "Home", key: .home, tint: "#1A1A1A")

        manager.open(youTube)
        manager.open(home)

        XCTAssertEqual(channel.launched, ["https://www.youtube.com"])
        XCTAssertEqual(channel.presses, [FakeChannel.Press(key: .home, direction: .short)])
    }

    func testTypeWithoutTextFieldDoesNotCrash() async throws {
        let (manager, channel) = try await makeConnectedManager()
        channel.emit(.textField(available: true))
        await waitUntil { manager.canType }

        channel.typeError = .noTextField
        manager.type("lofi")

        XCTAssertFalse(manager.canType)
        XCTAssertEqual(manager.state, .connected(tvOn: true))
        XCTAssertEqual(channel.typed, [])
    }

    func testTypeSendsTextWhenAFieldIsFocused() async throws {
        let (manager, channel) = try await makeConnectedManager()
        channel.emit(.textField(available: true))
        await waitUntil { manager.canType }

        manager.type("lofi")

        XCTAssertEqual(channel.typed, ["lofi"])
        XCTAssertTrue(manager.canType)
    }

    func testPowerWhenConnectedPressesPower() async throws {
        let (manager, channel) = try await makeConnectedManager()

        manager.power()

        XCTAssertEqual(channel.presses, [FakeChannel.Press(key: .power, direction: .short)])
        XCTAssertEqual(link.waker.macs, [])
    }

    func testPowerWhenUnreachableWakesAndReconnects() async {
        let manager = makeManager()
        link.openResults = [.failure(.unreachable)]
        clock.holds = true
        manager.appBecameActive()
        await waitUntil { manager.state == .unreachable && self.clock.delays == [1] }
        clock.holds = false

        manager.power()
        XCTAssertEqual(manager.state, .connecting)

        await waitUntil { manager.state == .connected(tvOn: true) }
        XCTAssertEqual(link.waker.macs, ["44:0f:b4:88:a4:9b"])
        XCTAssertEqual(link.waker.hosts, ["192.168.8.16"])
        XCTAssertEqual(link.openedHosts.count, 2)
        // The wake gets 3 s before the next attempt; the cut-short backoff wait was the 1.
        XCTAssertEqual(clock.delays, [1, 3])
    }

    func testPowerWhenUnreachableWithoutMACRetriesNow() async {
        let manager = makeManager(tv: PairedTV(host: "192.168.8.20", name: "Bedroom", mac: nil))
        link.openResults = [.failure(.unreachable)]
        clock.holds = true
        manager.appBecameActive()
        await waitUntil { manager.state == .unreachable && self.clock.delays == [1] }
        clock.holds = false

        manager.power()

        await waitUntil { manager.state == .connected(tvOn: true) }
        XCTAssertEqual(link.waker.macs, [])
        XCTAssertEqual(clock.delays, [1])
        XCTAssertEqual(link.openedHosts, ["192.168.8.20", "192.168.8.20"])
    }

    // MARK: - Pairing

    func testBadCodeKeepsPairingOpen() async {
        let manager = makeManager(tv: nil)
        link.pairingChannel.finishErrors = [.badCode]
        manager.appBecameActive()
        XCTAssertEqual(manager.state, .noTV)

        await manager.startPairing(host: "192.168.8.16", name: "TCL Smart TV Pro")
        XCTAssertEqual(manager.state, .pairing(.enterCode))

        await manager.submitCode("A1B2C3")
        XCTAssertEqual(manager.state, .pairing(.wrongCode))
        XCTAssertFalse(link.pairingChannel.cancelled)
        XCTAssertNil(manager.tv)

        await manager.submitCode("D4E5F6")
        XCTAssertEqual(link.pairingChannel.codes, ["A1B2C3", "D4E5F6"])
        XCTAssertEqual(link.pairingHosts, ["192.168.8.16"])
        XCTAssertEqual(manager.tv, knownTV)
        XCTAssertEqual(store.tv, knownTV)

        await waitUntil { manager.state == .connected(tvOn: true) }
        XCTAssertEqual(link.openedHosts, ["192.168.8.16"])
    }

    func testPairingAnotherTVSavesItWithoutMAC() async {
        let manager = makeManager(tv: nil)
        manager.appBecameActive()

        await manager.startPairing(host: "192.168.8.20", name: "Bedroom")
        await manager.submitCode("A1B2C3")

        XCTAssertEqual(store.tv, PairedTV(host: "192.168.8.20", name: "Bedroom", mac: nil))
        await waitUntil { manager.state == .connected(tvOn: true) }
    }

    func testPairingFailureExplainsAndEndsTheSession() async {
        let manager = makeManager(tv: nil)
        link.pairingChannel.startError = .unreachable
        manager.appBecameActive()

        await manager.startPairing(host: "192.168.8.16", name: "TCL Smart TV Pro")

        XCTAssertEqual(manager.state, .pairing(.failed("Can't reach the TV. Is it on and on the same Wi-Fi?")))
        XCTAssertTrue(link.pairingChannel.cancelled)
        await manager.submitCode("A1B2C3")
        XCTAssertEqual(link.pairingChannel.codes, [])
    }

    func testPairingAgainAfterNeedsPairingReplacesTheTV() async {
        let manager = makeManager()
        link.openResults = [.failure(.notPaired)]
        manager.appBecameActive()
        await waitForEnd(of: manager.connectTask)
        XCTAssertEqual(manager.state, .needsPairing)

        await manager.startPairing(host: "192.168.8.16", name: "Living room")
        await manager.submitCode("A1B2C3")

        await waitUntil { manager.state == .connected(tvOn: true) }
        XCTAssertEqual(store.tv?.name, "Living room")
        XCTAssertEqual(link.openedHosts.count, 2)
    }

    func testForgetTVClosesTheSessionAndClearsTheStore() async throws {
        let (manager, channel) = try await makeConnectedManager()

        manager.forgetTV()

        XCTAssertTrue(channel.closed)
        XCTAssertEqual(manager.state, .noTV)
        XCTAssertNil(manager.tv)
        XCTAssertNil(store.tv)
        manager.appWentBackground()
        manager.appBecameActive()
        XCTAssertNil(manager.connectTask)
        XCTAssertEqual(link.openedHosts.count, 1)
    }

    // MARK: - Stores and the live link

    func testUserDefaultsStoreRoundTrips() throws {
        let suite = "ConnectionManagerTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = UserDefaultsPairedTVStore(defaults: defaults)
        XCTAssertNil(store.load())

        store.save(knownTV)
        XCTAssertEqual(UserDefaultsPairedTVStore(defaults: defaults).load(), knownTV)
        XCTAssertNotNil(defaults.data(forKey: "pairedTV"))

        store.save(nil)
        XCTAssertNil(store.load())
        XCTAssertNil(defaults.object(forKey: "pairedTV"))
    }

    func testLivePairingCancelledBeforeStartThrowsClosed() async throws {
        let identity = try ClientIdentity.generate()
        let pairing = LiveLink(identityStore: MemoryIdentityStore(identity), clientName: "Test iPhone")
            .pairing(host: "127.0.0.1")

        pairing.cancel()

        do {
            try await pairing.start()
            XCTFail("start should throw after cancel")
        } catch {
            XCTAssertEqual(error as? TVLinkError, .closed)
        }
        do {
            try await pairing.finish(code: "A1B2C3")
            XCTFail("finish should throw without a started session")
        } catch {
            XCTAssertEqual(error as? TVLinkError, .closed)
        }
    }

    // MARK: - Waiting

    /// Waits (by yielding the main actor) until `condition` holds; fails after 2 s.
    private func waitUntil(
        _ condition: () -> Bool,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        let deadline = ContinuousClock.now + .seconds(2)
        while !condition() {
            guard ContinuousClock.now < deadline else {
                XCTFail("Timed out waiting for the condition", file: file, line: line)
                return
            }
            await Task.yield()
        }
    }

    /// Waits for the manager's retry loop to finish; fails after 2 s instead of hanging.
    private func waitForEnd(
        of task: Task<Void, Never>?,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        guard let task else { return }
        let watcher = TaskWatcher()
        Task {
            await task.value
            watcher.ended = true
        }
        await waitUntil({ watcher.ended }, file: file, line: line)
        await settle()
    }

    /// Lets work already queued by the manager run, so a test can check that nothing more happened.
    private func settle() async {
        for _ in 0..<100 { await Task.yield() }
    }
}

// MARK: - Fakes

/// A TV link that follows a script. Once `openResults` runs out the TV answers every open with a session
/// that is up and on. While `holdsOpens` is set, opens wait for `releaseOpens()`. Every pairing uses
/// `pairingChannel`; wakes go to `waker`.
final class FakeLink: TVLinking {
    var openResults: [Result<FakeChannel, TVLinkError>] = []
    var holdsOpens = false
    private var heldOpens: [CheckedContinuation<Void, Never>] = []
    private(set) var openedHosts: [String] = []
    private(set) var channels: [FakeChannel] = []
    let pairingChannel = FakePairing()
    private(set) var pairingHosts: [String] = []
    let waker = FakeWaker()

    @MainActor
    func openRemote(host: String) async throws -> RemoteChannel {
        openedHosts.append(host)
        if holdsOpens { await withCheckedContinuation { heldOpens.append($0) } }
        let channel = try openResults.isEmpty ? FakeChannel() : openResults.removeFirst().get()
        channels.append(channel)
        return channel
    }

    @MainActor
    func releaseOpens() {
        holdsOpens = false
        heldOpens.forEach { $0.resume() }
        heldOpens = []
    }

    func pairing(host: String) -> PairingChannel {
        pairingHosts.append(host)
        return pairingChannel
    }

    @MainActor
    func wake(mac: String, host: String) async throws {
        waker.wake(mac: mac, host: host)
    }
}

/// A remote session: records what the manager sends; the test pushes events with `emit`.
final class FakeChannel: RemoteChannel {
    struct Press: Equatable {
        let key: KeyCode
        let direction: KeyDirection
    }

    let events: AsyncStream<RemoteEvent>
    private let sink: AsyncStream<RemoteEvent>.Continuation
    private(set) var presses: [Press] = []
    private(set) var launched: [String] = []
    private(set) var typed: [String] = []
    var typeError: TVLinkError?
    private(set) var closed = false

    /// Like a session that `RemoteSession.open` returns: `.ready(isOn:)` is already waiting.
    init(isOn: Bool = true) {
        (events, sink) = AsyncStream<RemoteEvent>.makeStream()
        sink.yield(.ready(isOn: isOn))
    }

    func emit(_ event: RemoteEvent) {
        sink.yield(event)
        if case .closed = event { sink.finish() }
    }

    func send(_ key: KeyCode, _ direction: KeyDirection) {
        presses.append(Press(key: key, direction: direction))
    }

    func launch(appLink: String) {
        launched.append(appLink)
    }

    func type(_ text: String) throws {
        if let typeError { throw typeError }
        typed.append(text)
    }

    func close() {
        guard !closed else { return }
        closed = true
        emit(.closed(.closed))
    }
}

/// A pairing attempt. `finishErrors` are thrown by successive `finish` calls; after them every code is accepted.
final class FakePairing: PairingChannel {
    var startError: TVLinkError?
    var finishErrors: [TVLinkError] = []
    private(set) var codes: [String] = []
    private(set) var cancelled = false

    @MainActor
    func start() async throws {
        if let startError { throw startError }
    }

    @MainActor
    func finish(code: String) async throws {
        codes.append(code)
        if !finishErrors.isEmpty { throw finishErrors.removeFirst() }
    }

    func cancel() {
        cancelled = true
    }
}

final class FakeStore: PairedTVStore {
    private(set) var tv: PairedTV?

    init(_ tv: PairedTV?) {
        self.tv = tv
    }

    func load() -> PairedTV? { tv }

    func save(_ tv: PairedTV?) {
        self.tv = tv
    }
}

/// Records Wake-on-LAN requests.
final class FakeWaker {
    private(set) var macs: [String] = []
    private(set) var hosts: [String] = []

    func wake(mac: String, host: String) {
        macs.append(mac)
        hosts.append(host)
    }
}

/// Records the manager's waits. Normally they end at once; while `holds` is set a wait lasts until the
/// manager cancels it, so a test can act in the middle of a backoff.
@MainActor
final class FakeClock {
    private(set) var delays: [TimeInterval] = []
    var holds = false

    func sleep(_ delay: TimeInterval) async {
        delays.append(delay)
        if holds { try? await Task.sleep(for: .seconds(3600)) }
    }
}

@MainActor
private final class TaskWatcher {
    var ended = false
}

private struct MemoryIdentityStore: IdentityStore {
    let identity: ClientIdentity

    init(_ identity: ClientIdentity) {
        self.identity = identity
    }

    func load() throws -> ClientIdentity? { identity }
    func save(_ identity: ClientIdentity) throws {}
}
