import Foundation
import NIOCore

/// What the TV reports during a remote session.
public enum RemoteEvent: Equatable {
    /// Always the first event: the session is up and the TV's screen is on or off.
    case ready(isOn: Bool)
    /// The TV turned on or off.
    case power(isOn: Bool)
    case volume(level: Int, max: Int, muted: Bool)
    /// Typing now reaches a text field on the TV (sent when the TV first reports one).
    case textField(available: Bool)
    /// Package of the app in the foreground, sent when it changes.
    case currentApp(String)
    /// Always the last event: the session ended.
    case closed(TVLinkError)
}

/// A session on the TV's remote port (6466): sends keys, app links and text, and reports what the TV says.
///
/// The session answers the TV's configure, set_active and ping messages by itself. If nothing arrives
/// for 16 s (the TV pings about every 5 s) it ends with `.closed(.timeout)`. `send`, `launch`, `type`
/// and `close` may be called from any thread. Dropping the session, or cancelling the task that reads
/// `events`, closes the connection.
public final class RemoteSession {
    /// Features this client asks for: PING | KEY | IME | POWER | VOLUME | APP_LINK.
    static let requestedFeatures = 615
    static let connectTimeout: TimeInterval = 5
    /// How long the TV may take, after the TLS handshake, to send its first start message.
    static let startTimeout: TimeInterval = 5
    static let silenceTimeout: TimeInterval = 16

    public let events: AsyncStream<RemoteEvent>

    private let channel: TLSChannel
    private let sink: AsyncStream<RemoteEvent>.Continuation
    private let lock = NSLock()
    /// Counters of the TV's focused text field, nil until it reports one. Guarded by `lock`.
    private var textField: (imeCounter: Int, fieldCounter: Int)?
    /// Touched only by the inbound loop: first in `open`, then in the reader task, never both at once.
    private var activeFeatures = RemoteSession.requestedFeatures
    private var currentApp: String?

    private init(channel: TLSChannel) {
        self.channel = channel
        let (events, sink) = AsyncStream<RemoteEvent>.makeStream()
        self.events = events
        self.sink = sink
        sink.onTermination = { termination in
            if case .cancelled = termination { channel.close() }
        }
    }

    deinit {
        channel.close()
    }

    /// Connects to the TV and returns once it has reported its power state, so `.ready(isOn:)` is the first event.
    /// - Throws: `TVLinkError`: `.notPaired` when the TV rejects this device's certificate (also when the
    ///   rejection arrives after the TLS handshake), `.timeout` without a start message within 5 s, …
    public static func open(host: String, identity: ClientIdentity) async throws -> RemoteSession {
        try await open(
            host: host,
            port: TLSChannel.remotePort,
            identity: identity,
            startTimeout: startTimeout,
            silenceTimeout: silenceTimeout
        )
    }

    /// `open` with the port and timeouts injectable for tests.
    static func open(
        host: String,
        port: Int,
        identity: ClientIdentity,
        startTimeout: TimeInterval,
        silenceTimeout: TimeInterval
    ) async throws -> RemoteSession {
        let channel = try await TLSChannel.connect(
            host: host,
            port: port,
            identity: identity,
            timeout: connectTimeout,
            errorPort: TLSChannel.remotePort
        )
        let session = RemoteSession(channel: channel)
        var inbound = channel.messages.makeAsyncIterator()
        var early: [RemoteEvent] = []
        let isOn: Bool
        let timer = channel.failOnTimeout(after: startTimeout)
        do {
            isOn = try await session.handleUntilStart(&inbound, collecting: &early)
            timer.cancel()
        } catch {
            timer.cancel()
            session.close()
            throw TVLinkError.map(error, port: TLSChannel.remotePort)
        }
        session.sink.yield(.ready(isOn: isOn))
        early.forEach { session.sink.yield($0) }
        session.startReading(inbound, silenceTimeout: silenceTimeout)
        return session
    }

    public func send(_ key: KeyCode, _ direction: KeyDirection = .short) {
        channel.send(RemoteOutbound.key(key, direction))
    }

    public func launch(appLink: String) {
        channel.send(RemoteOutbound.appLink(appLink))
    }

    /// Replaces the contents of the text field focused on the TV with `text`. An empty `text` sends nothing.
    /// - Throws: `.noTextField` until the TV has reported a text field in this session.
    public func type(_ text: String) throws {
        guard let field = lock.withLock({ textField }) else { throw TVLinkError.noTextField }
        guard !text.isEmpty else { return }
        channel.send(RemoteOutbound.text(text, imeCounter: field.imeCounter, fieldCounter: field.fieldCounter))
    }

    /// Ends the session; `events` then delivers `.closed(.closed)` and finishes.
    public func close() {
        channel.close()
    }

    /// Handles messages until the TV's first start message and returns its power state.
    /// Events that arrive before it are appended to `early`.
    private func handleUntilStart(
        _ inbound: inout AsyncThrowingStream<[UInt8], Error>.AsyncIterator,
        collecting early: inout [RemoteEvent]
    ) async throws -> Bool {
        while let payload = try await inbound.next() {
            let message = try RemoteInbound.parse(payload)
            if case .start(let isOn) = message { return isOn }
            if let event = handle(message) { early.append(event) }
        }
        // Only a cancelled reader ends the stream without an error.
        throw TVLinkError.closed
    }

    /// Reads until the connection ends, then delivers `.closed` and finishes `events`.
    /// Holds the session weakly so that dropping it closes the connection (see `deinit`).
    private func startReading(
        _ inbound: AsyncThrowingStream<[UInt8], Error>.AsyncIterator,
        silenceTimeout: TimeInterval
    ) {
        let channel = channel
        let sink = sink
        Task { [weak self] in
            var inbound = inbound
            var watchdog = channel.failOnTimeout(after: silenceTimeout)
            let ending: TVLinkError
            do {
                while let payload = try await inbound.next() {
                    watchdog.cancel()
                    watchdog = channel.failOnTimeout(after: silenceTimeout)
                    let message = try RemoteInbound.parse(payload)
                    if let event = self?.handle(message) { sink.yield(event) }
                }
                ending = .closed
            } catch {
                ending = TVLinkError.map(error, port: TLSChannel.remotePort)
            }
            watchdog.cancel()
            channel.close()
            sink.yield(.closed(ending))
            sink.finish()
        }
    }

    /// Answers the TV's housekeeping messages and returns the event a message means for the app, if any.
    private func handle(_ message: RemoteInbound) -> RemoteEvent? {
        switch message {
        case .configure(let code1):
            activeFeatures = Self.requestedFeatures & code1
            channel.send(RemoteOutbound.configureReply(features: activeFeatures))
        case .setActive:
            channel.send(RemoteOutbound.setActiveReply(features: activeFeatures))
        case .ping(let val1):
            channel.send(RemoteOutbound.pingResponse(val1))
        case .start(let isOn):
            return .power(isOn: isOn)
        case .volume(let level, let max, let muted):
            return .volume(level: level, max: max, muted: muted)
        case .imeField(let imeCounter, let fieldCounter):
            let isFirst = lock.withLock { () -> Bool in
                defer { textField = (imeCounter, fieldCounter) }
                return textField == nil
            }
            return isFirst ? .textField(available: true) : nil
        case .currentApp(let app):
            guard app != currentApp else { return nil }
            currentApp = app
            return .currentApp(app)
        case .error, .unknown:
            break
        }
        return nil
    }
}
