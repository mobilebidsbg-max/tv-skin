import Foundation
import NIOCore
import NIOPosix
import NIOSSL

/// Why talking to the TV failed, in the terms the app shows to the user.
public enum TVLinkError: Error, Equatable {
    /// Nothing answers at that address: TV off, wrong IP, or another network.
    case unreachable
    /// The TV refused this device's certificate on the remote port: pair first.
    case notPaired
    /// The TV stopped answering in time.
    case timeout
    /// The connection ended, or was closed by this side.
    case closed
    /// The pairing code was wrong.
    case badCode
    /// iOS blocked access to the local network.
    case localNetworkDenied
    /// Text was sent while no text field on the TV is focused.
    case noTextField
    /// The TV sent something this client does not understand.
    case protocolError(String)

    /// Turns a low-level error into a `TVLinkError`.
    ///
    /// On the remote port (6466) the TV rejects an unknown client certificate with a TLS failure: the handshake
    /// fails, or under TLS 1.3 an alert arrives right after it. Only those errors mean `.notPaired`. A reset, a
    /// hang-up or an EOF, even in the middle of the handshake, is a dropped connection (`.closed`): a TV going to
    /// standby, rebooting or waking up does that too. Callers that have already received a message must use
    /// `map(_:port:afterMessage:)`.
    public static func map(_ error: Error, port: Int) -> TVLinkError {
        let onRemotePort = port == TLSChannel.remotePort
        switch error {
        case let error as TVLinkError:
            return error
        case is PairingError:
            return .badCode
        case let error as NIOConnectionError:
            // Happy Eyeballs wraps the per-address failures; a DNS failure leaves none.
            guard let first = error.connectionErrors.first else { return .unreachable }
            return map(first.error, port: port)
        case ChannelError.connectTimeout:
            return .unreachable
        case let error as IOError:
            switch error.errnoCode {
            case ECONNREFUSED, EHOSTUNREACH, ENETUNREACH, EHOSTDOWN, ENETDOWN, ETIMEDOUT:
                return .unreachable
            default:
                // Any other socket failure (ECONNRESET, EPIPE, ECONNABORTED, ENOTCONN, …) is a dropped
                // connection, not bad data.
                return .closed
            }
        case NIOSSLError.handshakeFailed(.sslError(let stack)) where stack.contains(where: isEOF):
            // NIOSSL reports a connection that closed during the handshake as a failed handshake.
            return .closed
        case NIOSSLError.handshakeFailed, is BoringSSLError:
            // Under TLS 1.3 a rejected client certificate arrives as an alert after the handshake (BoringSSLError).
            return onRemotePort ? .notPaired : .protocolError("TLS: \(error)")
        case NIOSSLError.uncleanShutdown, is ChannelError:
            return .closed
        default:
            return .protocolError(String(describing: error))
        }
    }

    /// `map` for an error that ends a connection which may already have carried a message. The TV rejects an
    /// unpaired certificate before it sends anything, so after a message `.notPaired` becomes `.closed`.
    static func map(_ error: Error, port: Int, afterMessage: Bool) -> TVLinkError {
        let mapped = map(error, port: port)
        return mapped == .notPaired && afterMessage ? .closed : mapped
    }

    /// The errors NIOSSL makes up when the connection closes during the handshake.
    private static func isEOF(_ error: BoringSSLInternalError) -> Bool {
        error == .eofDuringHandshake || error == .eofDuringAdditionalCertficiateChainValidation
    }
}
