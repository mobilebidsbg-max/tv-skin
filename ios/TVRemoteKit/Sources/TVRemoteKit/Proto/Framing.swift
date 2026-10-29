/// Every message on the wire is a protobuf payload prefixed by its length as a varint.
public enum Framing {
    /// Largest accepted payload: 1 MiB.
    public static let maxFrameSize = 1_048_576

    public static func frame(_ payload: [UInt8]) -> [UInt8] {
        var out: [UInt8] = []
        out.reserveCapacity(payload.count + 5)
        ProtoWriter.appendVarint(UInt64(payload.count), to: &out)
        out.append(contentsOf: payload)
        return out
    }
}

/// Reassembles length-prefixed frames from a byte stream that arrives in arbitrary chunks.
public struct FrameDecoder {
    private var buffer: [UInt8] = []

    public init() {}

    public mutating func append(_ bytes: [UInt8]) {
        buffer.append(contentsOf: bytes)
    }

    /// Returns the next complete payload, or nil if more bytes are needed.
    /// Throws `.frameTooLarge` as soon as an oversized length prefix is seen, and
    /// `.malformedVarint` for an invalid prefix; after either the stream is unusable.
    public mutating func next() throws -> [UInt8]? {
        var headerEnd = 0
        let length: UInt64
        do {
            length = try ProtoMessage.readVarint(buffer, at: &headerEnd)
        } catch ProtoError.truncated {
            return nil
        }
        guard length <= UInt64(Framing.maxFrameSize) else { throw ProtoError.frameTooLarge }
        let frameEnd = headerEnd + Int(length)
        guard buffer.count >= frameEnd else { return nil }
        let payload = Array(buffer[headerEnd..<frameEnd])
        buffer.removeFirst(frameEnd)
        return payload
    }
}
