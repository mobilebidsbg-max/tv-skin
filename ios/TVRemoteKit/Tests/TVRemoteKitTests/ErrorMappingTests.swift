import Foundation
import NIOCore
import NIOSSL
import XCTest
import TVRemoteKit

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

    func testDroppedConnectionOnRemotePortMeansNotPaired() {
        XCTAssertEqual(TVLinkError.map(NIOSSLError.uncleanShutdown, port: 6466), .notPaired)
        XCTAssertEqual(TVLinkError.map(IOError(errnoCode: ECONNRESET, reason: "read"), port: 6466), .notPaired)
    }

    func testDroppedConnectionOnPairingPortIsClosed() {
        XCTAssertEqual(TVLinkError.map(NIOSSLError.uncleanShutdown, port: 6467), .closed)
        XCTAssertEqual(TVLinkError.map(IOError(errnoCode: ECONNRESET, reason: "read"), port: 6467), .closed)
    }

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
