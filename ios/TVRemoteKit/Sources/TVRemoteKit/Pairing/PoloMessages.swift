/// Messages of the "polo" pairing handshake (TLS on port 6467).
/// Every message carries `protocol_version = 2` (field 1) and `status = 200` (field 2),
/// followed by exactly one payload field.
public enum PoloMessage {
    static let protocolVersion: UInt64 = 2
    static let statusOK: UInt64 = 200

    /// Field numbers of the payload (and the echoed status) in the outer message.
    enum Field {
        static let protocolVersion = 1
        static let status = 2
        static let pairingRequest = 10
        static let pairingRequestAck = 11
        static let options = 20
        static let configuration = 30
        static let configurationAck = 31
        static let secret = 40
        static let secretAck = 41
    }

    /// Service name the pairing request announces; fixed by the protocol.
    static let serviceName = "atvremote"
    /// Encoding type HEXADECIMAL, 6 symbols: the code the TV shows.
    static let hexadecimalEncoding: UInt64 = 3
    static let symbolLength: UInt64 = 6
    /// Role INPUT: this device sends key events.
    static let roleInput: UInt64 = 1

    public static func pairingRequest(clientName: String) -> [UInt8] {
        envelope { writer in
            writer.message(Field.pairingRequest) {
                $0.string(1, serviceName)
                $0.string(2, clientName)
            }
        }
    }

    public static func options() -> [UInt8] {
        envelope { writer in
            writer.message(Field.options) {
                $0.message(1, encoding)
                $0.varint(3, roleInput)
            }
        }
    }

    public static func configuration() -> [UInt8] {
        envelope { writer in
            writer.message(Field.configuration) {
                $0.message(1, encoding)
                $0.varint(2, roleInput)
            }
        }
    }

    public static func secret(_ secret: [UInt8]) -> [UInt8] {
        envelope { writer in
            writer.message(Field.secret) { $0.bytes(1, secret) }
        }
    }

    private static func encoding(_ writer: inout ProtoWriter) {
        writer.varint(1, hexadecimalEncoding)
        writer.varint(2, symbolLength)
    }

    private static func envelope(_ payload: (inout ProtoWriter) -> Void) -> [UInt8] {
        var writer = ProtoWriter()
        writer.varint(Field.protocolVersion, protocolVersion)
        writer.varint(Field.status, statusOK)
        payload(&writer)
        return writer.bytes
    }
}

/// A decoded reply from the TV during pairing.
public struct PoloReply: Equatable {
    public enum Kind: Equatable {
        case pairingRequestAck, options, configurationAck, secretAck
        /// Anything else, including error statuses that carry no payload.
        case other
    }

    public let status: Int
    public let kind: Kind

    public init(status: Int, kind: Kind) {
        self.status = status
        self.kind = kind
    }

    /// A missing status field decodes as 0, which is never a success status.
    public static func parse(_ bytes: [UInt8]) throws -> PoloReply {
        let message = try ProtoMessage(bytes)
        let status = Int(clamping: message.varint(PoloMessage.Field.status) ?? 0)
        let kind: Kind
        if message.has(PoloMessage.Field.pairingRequestAck) {
            kind = .pairingRequestAck
        } else if message.has(PoloMessage.Field.options) {
            kind = .options
        } else if message.has(PoloMessage.Field.configurationAck) {
            kind = .configurationAck
        } else if message.has(PoloMessage.Field.secretAck) {
            kind = .secretAck
        } else {
            kind = .other
        }
        return PoloReply(status: status, kind: kind)
    }
}
