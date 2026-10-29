import Foundation
import NIOCore
import NIOPosix
import NIOSSL
import NIOTLS

/// A TLS connection to one of the TV's ports that carries length-prefixed protobuf messages.
///
/// The TV's certificate is self-signed, so it is accepted without verification and without a hostname check.
/// This device presents its own certificate, which is how the TV recognizes a paired remote.
public final class TLSChannel {
    static let pairingPort = 6467
    static let remotePort = 6466

    /// Inbound message payloads in arrival order. It never finishes normally: when the connection ends it
    /// throws a `TVLinkError` (`.closed` after `close()`, `.notPaired` when the remote port rejects this device).
    /// Cancelling the task that reads it closes the connection.
    public let messages: AsyncThrowingStream<[UInt8], Error>

    private let channel: Channel

    private init(channel: Channel, messages: AsyncThrowingStream<[UInt8], Error>) {
        self.channel = channel
        self.messages = messages
    }

    deinit {
        close()
    }

    /// Connects and completes the TLS handshake.
    /// - Parameter timeout: limit for the TCP connect and, separately, for the handshake.
    /// - Throws: `TVLinkError` (`.unreachable`, `.notPaired`, `.timeout`, …).
    public static func connect(
        host: String,
        port: Int,
        identity: ClientIdentity,
        timeout: TimeInterval = 5
    ) async throws -> TLSChannel {
        try await connect(host: host, port: port, identity: identity, timeout: timeout, errorPort: port)
    }

    /// - Parameter errorPort: the TV port whose rules `TVLinkError.map` applies, normally `port`.
    ///   `RemoteSession` passes `remotePort` so a fake TV on another port gets the same mapping (`.notPaired`).
    static func connect(
        host: String,
        port: Int,
        identity: ClientIdentity,
        timeout: TimeInterval,
        errorPort: Int
    ) async throws -> TLSChannel {
        let sslContext: NIOSSLContext
        do {
            sslContext = try NIOSSLContext(configuration: tlsConfiguration(for: identity))
        } catch {
            throw TVLinkError.protocolError("client identity: \(error)")
        }

        let (messages, continuation) = AsyncThrowingStream<[UInt8], Error>.makeStream()
        let loop = MultiThreadedEventLoopGroup.singleton.next()
        let handshake = loop.makePromise(of: Void.self)
        let limit = TimeAmount(seconds: timeout)

        let channel: Channel
        do {
            channel = try await ClientBootstrap(group: loop)
                .connectTimeout(limit)
                .connect(host: host, port: port)
                .get()
        } catch {
            let mapped = TVLinkError.map(error, port: errorPort)
            Log.link.error("""
                Connecting to \(host, privacy: .public):\(port) failed: \(String(describing: error), privacy: .public) \
                (\(String(describing: mapped), privacy: .public))
                """)
            handshake.fail(mapped)
            continuation.finish(throwing: mapped)
            throw mapped
        }

        // When the consumer goes away (its task is cancelled or the stream is dropped), close the socket.
        // A normal end needs nothing: the handler that finishes the stream also closes the channel.
        continuation.onTermination = { termination in
            if case .cancelled = termination {
                channel.pipeline.fireErrorCaught(TVLinkError.closed)
            }
        }

        // Handlers go in after connect so only the connection that won (Happy Eyeballs may try several)
        // feeds the stream. The client speaks first in TLS, so nothing can arrive before this.
        do {
            try await loop.submit {
                let pipeline = channel.pipeline.syncOperations
                try pipeline.addHandler(NIOSSLClientHandler(context: sslContext, serverHostname: nil))
                try pipeline.addHandler(MessageHandler(port: errorPort, messages: continuation, handshake: handshake))
            }.get()
        } catch {
            channel.close(promise: nil)
            let mapped = TVLinkError.map(error, port: errorPort)
            handshake.fail(mapped)
            continuation.finish(throwing: mapped)
            throw mapped
        }

        let tlsChannel = TLSChannel(channel: channel, messages: messages)
        let timer = tlsChannel.failOnTimeout(after: timeout)
        defer { timer.cancel() }
        // The handler fails the promise with an already mapped `TVLinkError` and closes the channel.
        try await handshake.futureResult.get()
        return tlsChannel
    }

    /// Frames `payload` and sends it. Errors surface through `messages`.
    public func send(_ payload: [UInt8]) {
        channel.writeAndFlush(payload, promise: nil)
    }

    /// The TV's certificate (DER) from the TLS session.
    public func peerCertificateDER() async throws -> [UInt8] {
        let certificate: NIOSSLCertificate?
        do {
            certificate = try await channel.nioSSL_peerCertificate().get()
        } catch {
            // The TLS handler is gone: the channel was closed.
            throw TVLinkError.closed
        }
        guard let certificate else { throw TVLinkError.protocolError("TV sent no certificate") }
        do {
            return try certificate.toDERBytes()
        } catch {
            throw TVLinkError.protocolError("TV certificate: \(error)")
        }
    }

    /// Closes the connection; `messages` then throws `.closed`.
    public func close() {
        fail(.closed)
    }

    /// Ends the connection with `error`: `messages` throws it and the channel closes.
    /// Safe to call from any thread and after the channel has closed.
    func fail(_ error: TVLinkError) {
        channel.pipeline.fireErrorCaught(error)
    }

    /// Ends the connection with `.timeout` unless the returned task is cancelled within `seconds`.
    func failOnTimeout(after seconds: TimeInterval) -> Scheduled<Void> {
        let pipeline = channel.pipeline
        return channel.eventLoop.scheduleTask(in: TimeAmount(seconds: seconds)) {
            pipeline.fireErrorCaught(TVLinkError.timeout)
        }
    }

    private static func tlsConfiguration(for identity: ClientIdentity) throws -> TLSConfiguration {
        var tls = TLSConfiguration.makeClientConfiguration()
        tls.certificateVerification = .none
        tls.minimumTLSVersion = .tlsv12
        tls.certificateChain = [
            .certificate(try NIOSSLCertificate(bytes: Array(identity.certificatePEM.utf8), format: .pem))
        ]
        tls.privateKey = .privateKey(try NIOSSLPrivateKey(bytes: Array(identity.privateKeyPEM.utf8), format: .pem))
        return tls
    }
}

/// Sits behind the TLS handler: frames outbound payloads, reassembles inbound frames into `messages`,
/// reports the handshake, and ends the stream with the first error, mapped to `TVLinkError`.
private final class MessageHandler: ChannelDuplexHandler {
    typealias InboundIn = ByteBuffer
    typealias OutboundIn = [UInt8]
    typealias OutboundOut = ByteBuffer

    private let port: Int
    private let messages: AsyncThrowingStream<[UInt8], Error>.Continuation
    private var handshake: EventLoopPromise<Void>?
    private var decoder = FrameDecoder()
    private var receivedMessage = false
    private var ended = false

    init(port: Int, messages: AsyncThrowingStream<[UInt8], Error>.Continuation, handshake: EventLoopPromise<Void>) {
        self.port = port
        self.messages = messages
        self.handshake = handshake
    }

    func handlerAdded(context: ChannelHandlerContext) {
        // The connection may have dropped between connect and adding the handlers.
        if !context.channel.isActive {
            end(with: .closed)
        }
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        var buffer = unwrapInboundIn(data)
        decoder.append(buffer.readBytes(length: buffer.readableBytes) ?? [])
        do {
            while let payload = try decoder.next() {
                receivedMessage = true
                messages.yield(payload)
            }
        } catch {
            fail(context: context, error: error)
        }
    }

    func write(context: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
        let frame = Framing.frame(unwrapOutboundIn(data))
        context.write(wrapOutboundOut(context.channel.allocator.buffer(bytes: frame)), promise: promise)
    }

    func userInboundEventTriggered(context: ChannelHandlerContext, event: Any) {
        if case TLSUserEvent.handshakeCompleted = event {
            handshake?.succeed(())
            handshake = nil
        }
        context.fireUserInboundEventTriggered(event)
    }

    func errorCaught(context: ChannelHandlerContext, error: Error) {
        fail(context: context, error: error)
    }

    func channelInactive(context: ChannelHandlerContext) {
        // A close without an error first: the TV hung up cleanly.
        end(with: mapped(ChannelError.eof))
        context.fireChannelInactive()
    }

    private func fail(context: ChannelHandlerContext, error: Error) {
        end(with: mapped(error))
        context.close(promise: nil)
    }

    /// The first error wins; the stream and a pending handshake end at once rather than after the TLS shutdown.
    private func end(with error: TVLinkError) {
        guard !ended else { return }
        ended = true
        handshake?.fail(error)
        handshake = nil
        messages.finish(throwing: error)
    }

    /// Maps `error`, logging the first low-level error (the cause the app's own errors hide).
    private func mapped(_ error: Error) -> TVLinkError {
        let mapped = TVLinkError.map(error, port: port, afterMessage: receivedMessage)
        if !ended, !(error is TVLinkError) {
            Log.link.notice("""
                Connection on port \(self.port) ended: \(String(describing: error), privacy: .public) \
                (\(String(describing: mapped), privacy: .public))
                """)
        }
        return mapped
    }
}

private extension TimeAmount {
    init(seconds: TimeInterval) {
        self = .nanoseconds(Int64(seconds * 1_000_000_000))
    }
}
