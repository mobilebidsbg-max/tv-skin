/// Minimal protobuf encoder: just the wire types the Android TV Remote v2 protocol uses
/// (varint and length-delimited). Fields are written in call order.
public struct ProtoWriter {
    public var bytes: [UInt8] = []

    public init() {}

    public mutating func varint(_ field: Int, _ value: UInt64) {
        appendTag(field, wireType: 0)
        Self.appendVarint(value, to: &bytes)
    }

    public mutating func bool(_ field: Int, _ value: Bool) {
        varint(field, value ? 1 : 0)
    }

    public mutating func string(_ field: Int, _ value: String) {
        bytes(field, Array(value.utf8))
    }

    public mutating func bytes(_ field: Int, _ value: [UInt8]) {
        appendTag(field, wireType: 2)
        Self.appendVarint(UInt64(value.count), to: &bytes)
        bytes.append(contentsOf: value)
    }

    /// Writes a nested message: `build` fills a fresh writer whose bytes become the field's payload.
    public mutating func message(_ field: Int, _ build: (inout ProtoWriter) -> Void) {
        var inner = ProtoWriter()
        build(&inner)
        bytes(field, inner.bytes)
    }

    private mutating func appendTag(_ field: Int, wireType: UInt64) {
        Self.appendVarint(UInt64(field) << 3 | wireType, to: &bytes)
    }

    /// Base-128 little-endian varint, shared with `Framing`.
    static func appendVarint(_ value: UInt64, to out: inout [UInt8]) {
        var rest = value
        while rest >= 0x80 {
            out.append(UInt8(truncatingIfNeeded: rest) | 0x80)
            rest >>= 7
        }
        out.append(UInt8(rest))
    }
}
