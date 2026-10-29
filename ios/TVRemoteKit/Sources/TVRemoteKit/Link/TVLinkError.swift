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
    /// On the remote port (6466) the TV rejects an unknown client certificate by failing the TLS handshake
    /// or by dropping the connection right after it, so those errors mean `.notPaired`. Callers that have
    /// already received a message must not treat them that way (see `TLSChannel`).
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
            case ECONNRESET, EPIPE:
                return onRemotePort ? .notPaired : .closed
            default:
                // Any other socket failure (ECONNABORTED, ENOTCONN, …) is a dropped connection, not bad data.
                return .closed
            }
        case NIOSSLError.handshakeFailed, is BoringSSLError:
            // Under TLS 1.3 a rejected client certificate arrives as an alert after the handshake (BoringSSLError).
            return onRemotePort ? .notPaired : .protocolError("TLS: \(error)")
        case NIOSSLError.uncleanShutdown, ChannelError.eof:
            return onRemotePort ? .notPaired : .closed
        case is ChannelError:
            return .closed
        default:
            return .protocolError(String(describing: error))
        }
    }
}
