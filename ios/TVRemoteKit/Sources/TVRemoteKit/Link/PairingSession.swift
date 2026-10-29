import Foundation

/// One pairing attempt on the TV's pairing port (6467).
///
/// `start()` runs the handshake up to the point where the TV shows its 6-character code;
/// `finish(code:)` proves the code. A code rejected locally leaves the session open for another try;
/// any error from the TV, a timeout or a dropped connection ends it.
/// Call `start` and `finish` one after the other; `cancel` may be called at any time from anywhere.
public final class PairingSession {
    /// How long the TV may take to answer each step.
    static let replyTimeout: TimeInterval = 10
    private static let statusOK = 200
    private static let statusBadSecret = 402

    private let host: String
    private let port: Int
    private let identity: ClientIdentity
    private let clientName: String

    private let lock = NSLock()
    private var channel: TLSChannel?
    private var cancelled = false
    /// Used only by `start` and `finish`, which never overlap.
    private var replies: AsyncThrowingStream<[UInt8], Error>.AsyncIterator?

    public convenience init(host: String, identity: ClientIdentity, clientName: String) {
        self.init(host: host, port: TLSChannel.pairingPort, identity: identity, clientName: clientName)
    }

    init(host: String, port: Int, identity: ClientIdentity, clientName: String) {
        self.host = host
        self.port = port
        self.identity = identity
        self.clientName = clientName
    }

    /// Connects and walks the TV through pairing request, options and configuration.
    /// Returns once the TV acknowledges the configuration: the code is now on screen.
    /// - Throws: `TVLinkError`; `.closed` if the session was cancelled.
    public func start() async throws {
        let channel = try await TLSChannel.connect(host: host, port: port, identity: identity)
        guard adopt(channel) else {
            channel.close()
            throw TVLinkError.closed
        }
        do {
            try await exchange(PoloMessage.pairingRequest(clientName: clientName), expecting: .pairingRequestAck, on: channel)
            try await exchange(PoloMessage.options(), expecting: .options, on: channel)
            try await exchange(PoloMessage.configuration(), expecting: .configurationAck, on: channel)
        } catch {
            end(channel)
            throw TVLinkError.map(error, port: port)
        }
    }

    /// Sends the secret derived from `code` and waits for the TV to accept it.
    /// - Throws: `.badCode` for a malformed code or one that does not match the certificates (nothing is sent
    ///   and the session stays open), `.badCode` when the TV rejects the secret (status 402), or another `TVLinkError`.
    public func finish(code: String) async throws {
        guard let channel = lock.withLock({ cancelled ? nil : self.channel }) else { throw TVLinkError.closed }
        guard let code = PairingCode.normalize(code) else { throw TVLinkError.badCode }

        let secret: [UInt8]
        do {
            let server = try RSAPublicNumbers(certificateDER: try await channel.peerCertificateDER())
            secret = try PairingSecret.compute(client: try identity.publicNumbers(), server: server, code: code)
        } catch let error as PairingError {
            throw TVLinkError.map(error, port: port)
        } catch {
            end(channel)
            throw TVLinkError.map(error, port: port)
        }

        do {
            try await exchange(PoloMessage.secret(secret), expecting: .secretAck, on: channel)
        } catch {
            end(channel)
            throw TVLinkError.map(error, port: port)
        }
        // Paired: the TV now knows this device's certificate; the pairing connection is done.
        end(channel)
    }

    /// Ends the session; a pending or later `start`/`finish` throws `.closed`.
    public func cancel() {
        let channel = lock.withLock { () -> TLSChannel? in
            cancelled = true
            return self.channel
        }
        channel?.close()
    }

    /// Makes `channel` the session's connection unless the session was cancelled meanwhile.
    private func adopt(_ channel: TLSChannel) -> Bool {
        let (adopted, previous) = lock.withLock { () -> (Bool, TLSChannel?) in
            guard !cancelled else { return (false, nil) }
            defer { self.channel = channel }
            return (true, self.channel)
        }
        guard adopted else { return false }
        previous?.close()
        replies = channel.messages.makeAsyncIterator()
        return true
    }

    private func end(_ channel: TLSChannel) {
        channel.close()
        lock.withLock {
            if self.channel === channel { self.channel = nil }
        }
    }

    /// Sends `request` and waits up to `replyTimeout` for a reply of `kind` with status 200.
    private func exchange(_ request: [UInt8], expecting kind: PoloReply.Kind, on channel: TLSChannel) async throws {
        guard var iterator = replies else { throw TVLinkError.closed }
        channel.send(request)
        let timer = channel.failOnTimeout(after: Self.replyTimeout)
        defer { timer.cancel() }
        let payload = try await iterator.next()
        replies = iterator
        guard let payload else { throw TVLinkError.closed }

        let reply = try PoloReply.parse(payload)
        guard reply.status == Self.statusOK else {
            throw reply.status == Self.statusBadSecret
                ? TVLinkError.badCode
                : TVLinkError.protocolError("pairing status \(reply.status)")
        }
        guard reply.kind == kind else {
            throw TVLinkError.protocolError("expected \(kind) reply, got \(reply.kind)")
        }
    }
}
