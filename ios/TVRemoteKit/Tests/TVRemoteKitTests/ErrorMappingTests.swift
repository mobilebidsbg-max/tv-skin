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
}
