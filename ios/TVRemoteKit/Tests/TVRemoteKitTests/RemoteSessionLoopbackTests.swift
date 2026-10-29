import Foundation
import NIOCore
import NIOPosix
import NIOSSL
import XCTest
@testable import TVRemoteKit

/// Runs `RemoteSession` (and the lifetime of `TLSChannel`'s stream) against a local stand-in for the TV's
/// remote port, so the handshake replies, events, keep-alive and teardown are exercised without a real TV.
final class RemoteSessionLoopbackTests: XCTestCase {
    private static let clientIdentity = Result { try ClientIdentity.generate() }
    private static let tvIdentity = Result { try ClientIdentity.generate() }
    private static let youTube = "com.google.android.youtube.tv"

    /// The TV's side of connecting: configure (supported features 590) → set_active → start (and `extra`).
    /// 615 & 590 = 582, so a correct client answers both with 582.
    private static func script(isOn: Bool? = true, then extra: [[UInt8]] = []) -> FakeRemoteTV.Script {
        FakeRemoteTV.Script(
            onConnect: [TVMessage.configure(code1: 590)],
            after: [
                RemoteField.configure: [TVMessage.setActive],
                RemoteField.setActive: (isOn.map { [TVMessage.start(isOn: $0)] } ?? []) + extra,
            ]
        )
    }

    func testOpenAnswersTheTVAndReportsReadyFirst() async throws {
        let tv = try startTV(Self.script(then: [
            TVMessage.volume(level: 12, max: 100, muted: false),
            TVMessage.currentApp(Self.youTube),
            TVMessage.imeField(imeCounter: 4, fieldCounter: 7),
        ]))
        defer { tv.close() }

        let session = try await open(tv)
        let log = EventLog(session.events)

        XCTAssertEqual(tv.received.map(\.hex), [
            RemoteOutbound.configureReply(features: 582).hex,
            RemoteOutbound.setActiveReply(features: 582).hex,
        ])
        try await waitUntil("4 events") { log.events.count >= 4 }
        XCTAssertEqual(log.events, [
            .ready(isOn: true),
            .volume(level: 12, max: 100, muted: false),
            .currentApp(Self.youTube),
            .textField(available: true),
        ])
        session.close()
    }

    func testSendsKeysAppLinksAndText() async throws {
        let tv = try startTV(Self.script(then: [TVMessage.imeField(imeCounter: 4, fieldCounter: 7)]))
        defer { tv.close() }
        let session = try await open(tv)
        let log = EventLog(session.events)
        try await waitUntil("text field") { log.events.contains(.textField(available: true)) }

        session.send(.dpadUp)
        session.send(.dpadCenter, .startLong)
        session.send(.dpadCenter, .endLong)
        session.launch(appLink: "https://www.youtube.com")
        try session.type("hello")

        try await waitUntil("7 messages at the TV") { tv.received.count >= 7 }
        XCTAssertEqual(tv.received.dropFirst(2).map(\.hex), [
            RemoteOutbound.key(.dpadUp, .short).hex,
            RemoteOutbound.key(.dpadCenter, .startLong).hex,
            RemoteOutbound.key(.dpadCenter, .endLong).hex,
            RemoteOutbound.appLink("https://www.youtube.com").hex,
            RemoteOutbound.text("hello", imeCounter: 4, fieldCounter: 7).hex,
        ])
        session.close()
    }

    func testOpenWaitsForTheFirstStart() async throws {
        let tv = try startTV(Self.script(isOn: nil, then: [TVMessage.volume(level: 5, max: 100, muted: true)]))
        defer { tv.close() }

        let returned = Locked(false)
        let opening = Task {
            let session = try await self.open(tv)
            returned.value = true
            return session
        }
        try await waitUntil("handshake replies") { tv.received.count >= 2 }
        try await Task.sleep(nanoseconds: 300_000_000)
        XCTAssertFalse(returned.value, "open must not return before the TV's first start message")

        tv.send(TVMessage.start(isOn: false))
        let session = try await opening.value
        let log = EventLog(session.events)
        try await waitUntil("2 events") { log.events.count >= 2 }
        XCTAssertEqual(log.events, [.ready(isOn: false), .volume(level: 5, max: 100, muted: true)])
        session.close()
    }

    func testAnswersPingsAndTimesOutAfterSilence() async throws {
        let tv = try startTV(Self.script())
        defer { tv.close() }
        let session = try await open(tv, silenceTimeout: 0.5)
        let log = EventLog(session.events)

        // 6 pings 0.15 s apart keep the session open well past the 0.5 s silence limit.
        for val1 in 1...6 {
            try await Task.sleep(nanoseconds: 150_000_000)
            tv.send(TVMessage.ping(val1: val1))
        }
        try await waitUntil("6 ping responses") { tv.received.count >= 8 }
        let lastPing = Date()
        XCTAssertEqual(tv.received.dropFirst(2).map(\.hex), (1...6).map { RemoteOutbound.pingResponse($0).hex })
        XCTAssertEqual(log.events, [.ready(isOn: true)], "pings must keep the session open")

        try await waitUntil("timeout") { log.finished }
        XCTAssertEqual(log.events, [.ready(isOn: true), .closed(.timeout)])
        XCTAssertGreaterThan(Date().timeIntervalSince(lastPing), 0.3)
        try await waitUntil("TV sees the disconnect") { tv.disconnects == 1 }
    }

    func testLaterStartReportsPowerAndHangUpEndsTheSession() async throws {
        let tv = try startTV(Self.script())
        defer { tv.close() }
        let session = try await open(tv)
        let log = EventLog(session.events)

        tv.send(TVMessage.start(isOn: false))
        try await waitUntil("power event") { log.events.count >= 2 }
        tv.hangUp()
        try await waitUntil("session end") { log.finished }
        XCTAssertEqual(log.events, [.ready(isOn: true), .power(isOn: false), .closed(.closed)])
    }

    func testTypingWithoutATextFieldThrowsNoTextField() async throws {
        let tv = try startTV(Self.script())
        defer { tv.close() }
        let session = try await open(tv)

        XCTAssertThrowsError(try session.type("lofi")) { XCTAssertEqual($0 as? TVLinkError, .noTextField) }
        session.send(.home)
        try await waitUntil("key at the TV") { tv.received.count >= 3 }
        XCTAssertEqual(tv.received.dropFirst(2).map(\.hex), [RemoteOutbound.key(.home, .short).hex], "no text was sent")
        session.close()
    }

    /// Under TLS 1.3 the connect succeeds and the rejection arrives afterwards; `open` must still fail.
    func testRejectedCertificateIsNotPaired() async throws {
        let tv = try startTV(Self.script(), acceptsClient: false)
        defer { tv.close() }
        await assertThrows(.notPaired) { _ = try await self.open(tv) }
    }

    /// A TV going to standby or rebooting drops the connection in the middle of the handshake. That is a
    /// dropped connection to retry, not a rejected certificate.
    func testHangUpDuringTheHandshakeIsClosed() async throws {
        let tv = try DroppingTV.start(reset: false)
        defer { tv.close() }
        await assertThrows(.closed) { _ = try await self.open(port: tv.port) }
    }

    func testResetDuringTheHandshakeIsClosed() async throws {
        let tv = try DroppingTV.start(reset: true)
        defer { tv.close() }
        await assertThrows(.closed) { _ = try await self.open(port: tv.port) }
    }

    func testNoStartInTimeIsTimeout() async throws {
        let tv = try startTV(Self.script(isOn: nil))
        defer { tv.close() }
        await assertThrows(.timeout) { _ = try await self.open(tv, startTimeout: 0.3) }
        try await waitUntil("TV sees the disconnect") { tv.disconnects == 1 }
    }

    func testMalformedMessageEndsWithProtocolError() async throws {
        let tv = try startTV(Self.script())
        defer { tv.close() }
        let session = try await open(tv)
        let log = EventLog(session.events)

        tv.send([0x0b]) // field 1 with wire type 3 (a group): not decodable
        try await waitUntil("session end") { log.finished }
        guard case .closed(.protocolError)? = log.events.last else {
            return XCTFail("expected closed(protocolError), got \(log.events)")
        }
        try await waitUntil("TV sees the disconnect") { tv.disconnects == 1 }
    }

    func testCloseEndsTheSession() async throws {
        let tv = try startTV(Self.script())
        defer { tv.close() }
        let session = try await open(tv)
        let log = EventLog(session.events)

        session.close()
        try await waitUntil("session end") { log.finished }
        XCTAssertEqual(log.events, [.ready(isOn: true), .closed(.closed)])
        try await waitUntil("TV sees the disconnect") { tv.disconnects == 1 }
    }

    func testReleasingTheSessionClosesTheConnection() async throws {
        let tv = try startTV(Self.script())
        defer { tv.close() }
        weak var released: RemoteSession?
        do {
            let session = try await open(tv)
            released = session
        }
        try await waitUntil("TV sees the disconnect") { tv.disconnects == 1 }
        XCTAssertNil(released, "nothing may keep a dropped session alive")
    }

    func testCancellingTheEventConsumerClosesTheConnection() async throws {
        let tv = try startTV(Self.script())
        defer { tv.close() }
        let session = try await open(tv)
        let consumer = Task { for await _ in session.events {} }
        try await Task.sleep(nanoseconds: 100_000_000)

        consumer.cancel()
        try await waitUntil("TV sees the disconnect") { tv.disconnects == 1 }
        withExtendedLifetime(session) {}
    }

    func testCancellingTheMessageReaderClosesTheTLSConnection() async throws {
        let tv = try startTV(FakeRemoteTV.Script())
        defer { tv.close() }
        let channel = try await TLSChannel.connect(host: "127.0.0.1", port: tv.port, identity: try Self.clientIdentity.get())
        let reader = Task { for try await _ in channel.messages {} }
        try await waitUntil("TV sees the connection") { tv.connections == 1 }

        reader.cancel()
        try await waitUntil("TV sees the disconnect") { tv.disconnects == 1 }
        withExtendedLifetime(channel) {}
    }

    // MARK: - Helpers

    private func startTV(_ script: FakeRemoteTV.Script, acceptsClient: Bool = true) throws -> FakeRemoteTV {
        try FakeRemoteTV.start(identity: try Self.tvIdentity.get(), script: script, acceptsClient: acceptsClient)
    }

    private func open(
        _ tv: FakeRemoteTV,
        startTimeout: TimeInterval = 5,
        silenceTimeout: TimeInterval = 16
    ) async throws -> RemoteSession {
        try await open(port: tv.port, startTimeout: startTimeout, silenceTimeout: silenceTimeout)
    }

    private func open(
        port: Int,
        startTimeout: TimeInterval = 5,
        silenceTimeout: TimeInterval = 16
    ) async throws -> RemoteSession {
        try await RemoteSession.open(
            host: "127.0.0.1",
            port: port,
            identity: try Self.clientIdentity.get(),
            startTimeout: startTimeout,
            silenceTimeout: silenceTimeout
        )
    }

    private struct WaitTimeout: Error {
        let what: String
    }

    /// Polls `condition` every 20 ms; throws (failing the test) if it stays false for `timeout` seconds.
    private func waitUntil(_ what: String, timeout: TimeInterval = 3, _ condition: () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            guard Date() < deadline else { throw WaitTimeout(what: what) }
            try await Task.sleep(nanoseconds: 20_000_000)
        }
    }

    private func assertThrows(
        _ expected: TVLinkError,
        file: StaticString = #filePath,
        line: UInt = #line,
        _ body: () async throws -> Void
    ) async {
        do {
            try await body()
            XCTFail("expected \(expected)", file: file, line: line)
        } catch {
            XCTAssertEqual(error as? TVLinkError, expected, file: file, line: line)
        }
    }
}

/// Messages the TV sends, built the way the TV encodes them (proto3: false and 0 are left off).
private enum TVMessage {
    static func configure(code1: Int) -> [UInt8] {
        build(RemoteField.configure) {
            $0.varint(1, UInt64(code1))
            $0.message(2) { deviceInfo in
                deviceInfo.string(1, "Smart TV Pro")
                deviceInfo.string(2, "TCL")
            }
        }
    }

    static let setActive = build(RemoteField.setActive) { _ in }

    static func ping(val1: Int) -> [UInt8] {
        build(RemoteField.pingRequest) { $0.varint(1, UInt64(val1)) }
    }

    static func start(isOn: Bool) -> [UInt8] {
        build(RemoteField.start) { if isOn { $0.bool(1, true) } }
    }

    static func volume(level: Int, max: Int, muted: Bool) -> [UInt8] {
        build(RemoteField.setVolumeLevel) { volume in
            volume.string(3, "TCL")
            volume.varint(6, UInt64(max))
            volume.varint(7, UInt64(level))
            if muted { volume.bool(8, true) }
        }
    }

    static func currentApp(_ package: String) -> [UInt8] {
        build(RemoteField.imeKeyInject) { inject in
            inject.message(1) { $0.string(12, package) }
        }
    }

    static func imeField(imeCounter: Int, fieldCounter: Int) -> [UInt8] {
        build(RemoteField.imeBatchEdit) { edit in
            edit.varint(1, UInt64(imeCounter))
            edit.varint(2, UInt64(fieldCounter))
        }
    }

    private static func build(_ field: Int, _ body: (inout ProtoWriter) -> Void) -> [UInt8] {
        var writer = ProtoWriter()
        writer.message(field, body)
        return writer.bytes
    }
}

/// Plays the TV's remote port on 127.0.0.1: TLS with its own certificate, requires a client certificate
/// (rejecting it when `acceptsClient` is false), records what the client sends and follows a script.
private final class FakeRemoteTV: @unchecked Sendable {
    struct Script {
        /// Sent as soon as a client connects (NIOSSL holds them until the handshake is done).
        var onConnect: [[UInt8]] = []
        /// Sent after the client's message that sets this field of `RemoteMessage`.
        var after: [Int: [[UInt8]]] = [:]
    }

    let port: Int
    private let server: Channel
    private let lock = NSLock()
    private var connection: Channel?
    private var payloads: [[UInt8]] = []
    private var connectCount = 0
    private var disconnectCount = 0

    /// Payloads from the client, in arrival order.
    var received: [[UInt8]] { lock.withLock { payloads } }
    var connections: Int { lock.withLock { connectCount } }
    var disconnects: Int { lock.withLock { disconnectCount } }

    private init(server: Channel) {
        self.server = server
        self.port = server.localAddress!.port!
    }

    static func start(identity: ClientIdentity, script: Script, acceptsClient: Bool) throws -> FakeRemoteTV {
        var tls = TLSConfiguration.makeServerConfiguration(
            certificateChain: [.certificate(try NIOSSLCertificate(bytes: Array(identity.certificatePEM.utf8), format: .pem))],
            privateKey: .privateKey(try NIOSSLPrivateKey(bytes: Array(identity.privateKeyPEM.utf8), format: .pem))
        )
        tls.certificateVerification = .noHostnameVerification
        let context = try NIOSSLContext(configuration: tls)

        let box = Box()
        let server = try ServerBootstrap(group: MultiThreadedEventLoopGroup.singleton)
            .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .childChannelInitializer { channel in
                channel.eventLoop.makeCompletedFuture {
                    let sync = channel.pipeline.syncOperations
                    // A paired TV knows the client's certificate; this one either accepts or rejects any.
                    try sync.addHandler(NIOSSLServerHandler(context: context) { _, promise in
                        promise.succeed(acceptsClient ? .certificateVerified : .failed)
                    })
                    try sync.addHandler(Handler(tv: box, script: script))
                }
            }
            .bind(host: "127.0.0.1", port: 0)
            .wait()
        let tv = FakeRemoteTV(server: server)
        box.tv = tv
        return tv
    }

    /// Sends one message to the connected client.
    func send(_ payload: [UInt8]) {
        lock.withLock { connection }?.writeAndFlush(ByteBuffer(bytes: Framing.frame(payload)), promise: nil)
    }

    /// Drops the client connection.
    func hangUp() {
        lock.withLock { connection }?.close(promise: nil)
    }

    func close() {
        hangUp()
        server.close(promise: nil)
    }

    private func connected(_ channel: Channel) {
        lock.withLock {
            connection = channel
            connectCount += 1
        }
    }

    private func disconnected() {
        lock.withLock {
            connection = nil
            disconnectCount += 1
        }
    }

    private func record(_ payload: [UInt8]) {
        lock.withLock { payloads.append(payload) }
    }

    /// Lets the child handlers reach the server object created after binding.
    private final class Box: @unchecked Sendable {
        var tv: FakeRemoteTV?
    }

    private final class Handler: ChannelInboundHandler {
        typealias InboundIn = ByteBuffer
        typealias OutboundOut = ByteBuffer

        private let tv: Box
        private let script: Script
        private var decoder = FrameDecoder()

        init(tv: Box, script: Script) {
            self.tv = tv
            self.script = script
        }

        func channelActive(context: ChannelHandlerContext) {
            tv.tv?.connected(context.channel)
            send(script.onConnect, context: context)
            context.fireChannelActive()
        }

        func channelInactive(context: ChannelHandlerContext) {
            tv.tv?.disconnected()
            context.fireChannelInactive()
        }

        func channelRead(context: ChannelHandlerContext, data: NIOAny) {
            var buffer = unwrapInboundIn(data)
            decoder.append(buffer.readBytes(length: buffer.readableBytes) ?? [])
            do {
                while let payload = try decoder.next() {
                    tv.tv?.record(payload)
                    if let field = try ProtoMessage(payload).fieldNumbers.first, let replies = script.after[field] {
                        send(replies, context: context)
                    }
                }
            } catch {
                context.close(promise: nil)
            }
        }

        func errorCaught(context: ChannelHandlerContext, error: Error) {
            context.close(promise: nil)
        }

        private func send(_ payloads: [[UInt8]], context: ChannelHandlerContext) {
            for payload in payloads {
                context.write(wrapOutboundOut(ByteBuffer(bytes: Framing.frame(payload))), promise: nil)
            }
            context.flush()
        }
    }
}

/// A TV on its way down, on 127.0.0.1: it accepts the TCP connection and drops it as soon as the client's
/// first handshake message arrives, so the client is in the middle of the TLS handshake. With `reset` it sends a
/// TCP reset instead of closing normally.
private final class DroppingTV {
    let port: Int
    private let server: Channel

    private init(server: Channel) {
        self.server = server
        port = server.localAddress!.port!
    }

    static func start(reset: Bool) throws -> DroppingTV {
        let server = try ServerBootstrap(group: MultiThreadedEventLoopGroup.singleton)
            .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .childChannelInitializer { channel in
                channel.eventLoop.makeCompletedFuture {
                    try channel.pipeline.syncOperations.addHandler(Dropper(reset: reset))
                }
            }
            .bind(host: "127.0.0.1", port: 0)
            .wait()
        return DroppingTV(server: server)
    }

    func close() {
        server.close(promise: nil)
    }

    private final class Dropper: ChannelInboundHandler {
        typealias InboundIn = ByteBuffer

        private let reset: Bool

        init(reset: Bool) {
            self.reset = reset
        }

        func channelRead(context: ChannelHandlerContext, data: NIOAny) {
            if reset, let socket = context.channel as? SocketOptionProvider {
                // A zero linger time makes close() send a reset. On the event loop this takes effect at once.
                _ = socket.setSoLinger(linger(l_onoff: 1, l_linger: 0))
            }
            context.close(promise: nil)
        }
    }
}

/// Collects a session's events in the background.
private final class EventLog: @unchecked Sendable {
    private let lock = NSLock()
    private var items: [RemoteEvent] = []
    private var ended = false

    var events: [RemoteEvent] { lock.withLock { items } }
    /// The stream has finished.
    var finished: Bool { lock.withLock { ended } }

    init(_ stream: AsyncStream<RemoteEvent>) {
        Task {
            for await event in stream {
                lock.withLock { items.append(event) }
            }
            lock.withLock { ended = true }
        }
    }
}

/// A value shared between a test and a task it starts.
private final class Locked<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: Value

    init(_ value: Value) {
        stored = value
    }

    var value: Value {
        get { lock.withLock { stored } }
        set { lock.withLock { stored = newValue } }
    }
}
