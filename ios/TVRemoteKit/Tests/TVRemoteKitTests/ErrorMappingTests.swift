import Foundation
import NIOCore
import NIOSSL
import XCTest
@testable import TVRemoteKit

final class ErrorMappingTests: XCTestCase {
    func testHandshakeFailureOnRemotePortMeansNotPaired() {
        XCTAssertEqual(TVLinkError.map(NIOSSLError.handshakeFailed(.sslError([])), port: 6466), .notPaired)
    }

    func testConnectionRefusedIsUnreachable() {
        XCTAssertEqual(TVLinkError.map(IOError(errnoCode: ECONNREFUSED, reason: "connect"), port: 6466), .unreachable)
    }

    func testHostUnreachableIsUnreachable() {
        XCTAssertEqual(TVLinkError.map(IOError(errnoCode: EHOSTUNREACH, reason: "connect"), port: 6466), .unreachable)
    }

    func testNetworkUnreachableIsUnreachable() {
        XCTAssertEqual(TVLinkError.map(IOError(errnoCode: ENETUNREACH, reason: "connect"), port: 6467), .unreachable)
    }

    func testConnectTimeoutIsUnreachable() {
        XCTAssertEqual(TVLinkError.map(ChannelError.connectTimeout(.seconds(5)), port: 6466), .unreachable)
    }

    /// Under TLS 1.3 the TV rejects the certificate with an alert after the handshake.
    func testTLSAlertOnRemotePortMeansNotPaired() {
        XCTAssertEqual(TVLinkError.map(BoringSSLError.sslError([]), port: 6466), .notPaired)
    }

    /// A TV going to standby, rebooting or waking up drops connections too: that is no reason to pair again.
    func testDroppedConnectionOnRemotePortIsClosed() {
        for error in Self.droppedConnectionErrors {
            XCTAssertEqual(TVLinkError.map(error, port: 6466), .closed, "\(error)")
        }
    }

    func testDroppedConnectionOnPairingPortIsClosed() {
        for error in Self.droppedConnectionErrors {
            XCTAssertEqual(TVLinkError.map(error, port: 6467), .closed, "\(error)")
        }
    }

    /// The `.notPaired` gate: the TV rejects a certificate before it sends anything, so once a message has
    /// arrived a TLS failure is a plain close.
    func testTLSFailureAfterAMessageIsClosed() {
        XCTAssertEqual(TVLinkError.map(BoringSSLError.sslError([]), port: 6466, afterMessage: true), .closed)
        XCTAssertEqual(
            TVLinkError.map(NIOSSLError.handshakeFailed(.sslError([])), port: 6466, afterMessage: true),
            .closed
        )
        XCTAssertEqual(TVLinkError.map(BoringSSLError.sslError([]), port: 6466, afterMessage: false), .notPaired)
    }

    func testOtherErrorsAfterAMessageMapAsBefore() {
        XCTAssertEqual(TVLinkError.map(TVLinkError.timeout, port: 6466, afterMessage: true), .timeout)
        XCTAssertEqual(TVLinkError.map(ProtoError.truncated, port: 6466, afterMessage: true), .protocolError("truncated"))
        XCTAssertEqual(
            TVLinkError.map(IOError(errnoCode: ECONNREFUSED, reason: "connect"), port: 6466, afterMessage: true),
            .unreachable
        )
    }

    /// What NIO reports when the other side hangs up or resets, during the handshake or after it.
    private static let droppedConnectionErrors: [Error] = [
        NIOSSLError.uncleanShutdown,
        NIOSSLError.handshakeFailed(.sslError([.eofDuringHandshake])),
        NIOSSLError.handshakeFailed(.sslError([.eofDuringAdditionalCertficiateChainValidation])),
        ChannelError.eof,
        IOError(errnoCode: ECONNRESET, reason: "read"),
        IOError(errnoCode: EPIPE, reason: "write"),
    ]

    func testHandshakeFailureOnPairingPortIsNotNotPaired() {
        XCTAssertNotEqual(TVLinkError.map(NIOSSLError.handshakeFailed(.sslError([])), port: 6467), .notPaired)
    }

    func testWrongCodeIsBadCode() {
        XCTAssertEqual(TVLinkError.map(PairingError.codeMismatch, port: 6467), .badCode)
        XCTAssertEqual(TVLinkError.map(PairingError.invalidCode, port: 6467), .badCode)
    }

    func testAlreadyMappedErrorPassesThrough() {
        XCTAssertEqual(TVLinkError.map(TVLinkError.timeout, port: 6466), .timeout)
    }

    /// A socket error that does not mean "unreachable" or "not paired" is a dropped connection,
    /// so the app reconnects instead of reporting a protocol problem.
    func testUnlistedSocketErrorsAreClosed() {
        XCTAssertEqual(TVLinkError.map(IOError(errnoCode: ECONNABORTED, reason: "read"), port: 6466), .closed)
        XCTAssertEqual(TVLinkError.map(IOError(errnoCode: ENOTCONN, reason: "write"), port: 6466), .closed)
        XCTAssertEqual(TVLinkError.map(IOError(errnoCode: ENOTCONN, reason: "write"), port: 6467), .closed)
        XCTAssertEqual(TVLinkError.map(IOError(errnoCode: EPIPE, reason: "write"), port: 6467), .closed)
    }

    func testDecodeFailuresAreProtocolErrors() {
        for error in [ProtoError.truncated, .malformedVarint, .frameTooLarge, .unsupportedWireType(3)] {
            guard case .protocolError = TVLinkError.map(error, port: 6466) else {
                return XCTFail("\(error) should map to protocolError")
            }
        }
    }
}
