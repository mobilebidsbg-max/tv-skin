import Foundation
import NIOCore
import NIOPosix
import NIOSSL
import XCTest
@testable import TVRemoteKit

/// Runs `PairingSession` and `TLSChannel` against a local stand-in for the TV's pairing port,
/// so the TLS setup, framing and the polo handshake are exercised without a real TV.
final class PairingLoopbackTests: XCTestCase {
    private static let clientIdentity = Result { try ClientIdentity.generate() }
    private static let tvIdentity = Result { try ClientIdentity.generate() }

    func testPairsWithTheCodeShownOnTheTV() async throws {
        let tv = try FakePairingTV.start(identity: try Self.tvIdentity.get(), acceptsSecret: true)
        defer { tv.close() }
        let session = try makeSession(port: tv.port)

        try await session.start()
        XCTAssertEqual(tv.receivedFields, [10, 20, 30])
        XCTAssertEqual(tv.clientNames, ["loopback test"])

        try await session.finish(code: try validCode())
        XCTAssertEqual(tv.receivedFields, [10, 20, 30, 40])
        XCTAssertEqual(tv.secretMatched, [true])
    }

    func testWrongCodeIsRejectedWithoutSendingAndCanBeRetried() async throws {
        let tv = try FakePairingTV.start(identity: try Self.tvIdentity.get(), acceptsSecret: true)
        defer { tv.close() }
        let session = try makeSession(port: tv.port)
        try await session.start()

        let code = try validCode()
        let wrongFirstByte = (UInt8(code.prefix(2), radix: 16)! &+ 1)
        let wrongCode = String(format: "%02X", wrongFirstByte) + code.dropFirst(2)
        await assertThrows(.badCode) { try await session.finish(code: wrongCode) }
        await assertThrows(.badCode) { try await session.finish(code: "12345") }
        XCTAssertEqual(tv.receivedFields, [10, 20, 30], "nothing is sent for a locally rejected code")

        try await session.finish(code: code.lowercased())
        XCTAssertEqual(tv.secretMatched, [true])
    }

    func testSecretRejectedByTVIsBadCode() async throws {
        let tv = try FakePairingTV.start(identity: try Self.tvIdentity.get(), acceptsSecret: false)
        defer { tv.close() }
        let session = try makeSession(port: tv.port)
        try await session.start()

        await assertThrows(.badCode) { try await session.finish(code: try self.validCode()) }
        XCTAssertEqual(tv.receivedFields, [10, 20, 30, 40])
    }

    func testClosedPortIsUnreachable() async throws {
        let port = try FakePairingTV.unusedPort()
        await assertThrows(.unreachable) {
            _ = try await TLSChannel.connect(host: "127.0.0.1", port: port, identity: try Self.clientIdentity.get())
        }
    }

    func testCancelEndsAPendingStart() async throws {
        let tv = try FakePairingTV.start(identity: try Self.tvIdentity.get(), acceptsSecret: true, silent: true)
        defer { tv.close() }
        let session = try makeSession(port: tv.port)
        let started = Task { try await session.start() }
        try await Task.sleep(nanoseconds: 300_000_000)
        session.cancel()
        do {
            try await started.value
            XCTFail("start() should fail after cancel()")
        } catch {
            XCTAssertEqual(error as? TVLinkError, .closed)
        }
    }

    // MARK: - Helpers

    private func makeSession(port: Int) throws -> PairingSession {
        PairingSession(host: "127.0.0.1", port: port, identity: try Self.clientIdentity.get(), clientName: "loopback test")
    }

    /// The one code (with last four digits A1B2) whose first byte matches the certificates' digest.
    private func validCode() throws -> String {
        let client = try Self.clientIdentity.get().publicNumbers()
        let server = try Self.tvIdentity.get().publicNumbers()
        for first in 0...255 {
            let code = String(format: "%02X", first) + "A1B2"
            if (try? PairingSecret.compute(client: client, server: server, code: code)) != nil { return code }
        }
        throw PairingError.codeMismatch
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

/// Plays the TV's side of the polo handshake on 127.0.0.1: TLS with its own certificate,
/// requires a client certificate, answers each step, and checks the secret against the code math.
private final class FakePairingTV: @unchecked Sendable {
    let port: Int
    private let channel: Channel
    private let lock = NSLock()
    private var fields: [Int] = []
    private var names: [String] = []
    private var matches: [Bool] = []

    var receivedFields: [Int] { lock.withLock { fields } }
    var clientNames: [String] { lock.withLock { names } }
    var secretMatched: [Bool] { lock.withLock { matches } }

    private init(channel: Channel) {
        self.channel = channel
        self.port = channel.localAddress!.port!
    }

    /// - Parameter silent: never answer, to leave the client waiting.
    static func start(identity: ClientIdentity, acceptsSecret: Bool, silent: Bool = false) throws -> FakePairingTV {
        var tls = TLSConfiguration.makeServerConfiguration(
            certificateChain: [.certificate(try NIOSSLCertificate(bytes: Array(identity.certificatePEM.utf8), format: .pem))],
            privateKey: .privateKey(try NIOSSLPrivateKey(bytes: Array(identity.privateKeyPEM.utf8), format: .pem))
        )
        // Ask for the client certificate; any certificate is accepted, like the TV does on its pairing port.
        tls.certificateVerification = .noHostnameVerification
        let context = try NIOSSLContext(configuration: tls)
        let serverNumbers = try identity.publicNumbers()

        let box = Box()
        let channel = try ServerBootstrap(group: MultiThreadedEventLoopGroup.singleton)
            .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .childChannelInitializer { channel in
                channel.eventLoop.makeCompletedFuture {
                    let sync = channel.pipeline.syncOperations
                    try sync.addHandler(NIOSSLServerHandler(context: context) { _, promise in
                        promise.succeed(.certificateVerified)
                    })
                    try sync.addHandler(Handler(
                        tv: box,
                        serverNumbers: serverNumbers.sendable,
                        acceptsSecret: acceptsSecret,
                        silent: silent
                    ))
                }
            }
            .bind(host: "127.0.0.1", port: 0)
            .wait()
        let tv = FakePairingTV(channel: channel)
        box.tv = tv
        return tv
    }

    /// A port nothing listens on: bound once, then released.
    static func unusedPort() throws -> Int {
        let channel = try ServerBootstrap(group: MultiThreadedEventLoopGroup.singleton)
            .bind(host: "127.0.0.1", port: 0)
            .wait()
        let port = channel.localAddress!.port!
        try channel.close().wait()
        return port
    }

    func close() {
        channel.close(promise: nil)
    }

    private func record(field: Int, name: String? = nil, matched: Bool? = nil) {
        lock.withLock {
            fields.append(field)
            if let name { names.append(name) }
            if let matched { matches.append(matched) }
        }
    }

    /// Lets the child handlers reach the server object created after binding.
    private final class Box: @unchecked Sendable {
        var tv: FakePairingTV?
    }

    private final class Handler: ChannelInboundHandler {
        typealias InboundIn = ByteBuffer
        typealias OutboundOut = ByteBuffer

        private let tv: Box
        private let serverNumbers: SendableNumbers
        private let acceptsSecret: Bool
        private let silent: Bool
        private var decoder = FrameDecoder()

        init(tv: Box, serverNumbers: SendableNumbers, acceptsSecret: Bool, silent: Bool) {
            self.tv = tv
            self.serverNumbers = serverNumbers
            self.acceptsSecret = acceptsSecret
            self.silent = silent
        }

        func channelRead(context: ChannelHandlerContext, data: NIOAny) {
            var buffer = unwrapInboundIn(data)
            decoder.append(buffer.readBytes(length: buffer.readableBytes) ?? [])
            do {
                while let payload = try decoder.next() {
                    if let reply = try answer(payload, context: context), !silent {
                        context.writeAndFlush(wrapOutboundOut(ByteBuffer(bytes: Framing.frame(reply))), promise: nil)
                    }
                }
            } catch {
                context.close(promise: nil)
            }
        }

        private func answer(_ payload: [UInt8], context: ChannelHandlerContext) throws -> [UInt8]? {
            let message = try ProtoMessage(payload)
            switch message.fieldNumbers.last {
            case 10:
                tv.tv?.record(field: 10, name: try message.message(10)?.string(2))
                return Array(hex: "080210c8015a00")
            case 20:
                tv.tv?.record(field: 20)
                return Array(hex: "080210c801a201080a04080310061801")
            case 30:
                tv.tv?.record(field: 30)
                return Array(hex: "080210c801fa0100")
            case 40:
                let secret = try message.message(40)?.bytes(1)
                let peer = try context.channel.pipeline.syncOperations.nioSSL_peerCertificate()!.toDERBytes()
                let client = try RSAPublicNumbers(certificateDER: peer)
                let matched = Self.secretMatches(secret, client: client, server: serverNumbers.value)
                tv.tv?.record(field: 40, matched: matched)
                return acceptsSecret && matched ? Array(hex: "080210c801ca02020a00") : Array(hex: "0802109203")
            default:
                return nil
            }
        }

        /// What the TV does: recompute the digest for its own code and compare.
        private static func secretMatches(_ secret: [UInt8]?, client: RSAPublicNumbers, server: RSAPublicNumbers) -> Bool {
            guard let secret, secret.count == 32 else { return false }
            let code = String(format: "%02X", secret[0]) + "A1B2"
            return (try? PairingSecret.compute(client: client, server: server, code: code)) == secret
        }
    }
}

/// RSA numbers carried into NIO's `@Sendable` initializer.
private struct SendableNumbers: Sendable {
    let modulus: [UInt8]
    let exponent: [UInt8]
    var value: RSAPublicNumbers { RSAPublicNumbers(modulus: modulus, exponent: exponent) }
}

private extension RSAPublicNumbers {
    var sendable: SendableNumbers { SendableNumbers(modulus: modulus, exponent: exponent) }
}
