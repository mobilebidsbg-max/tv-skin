import Foundation

public enum ProtoError: Error, Equatable {
    /// Input ended in the middle of a field.
    case truncated
    /// A varint ran past 10 bytes or overflowed 64 bits.
    case malformedVarint
    /// A frame length prefix exceeded `Framing.maxFrameSize`.
    case frameTooLarge
    /// A wire type other than varint, fixed64, length-delimited or fixed32 (e.g. groups).
    case unsupportedWireType(Int)
}

/// A decoded protobuf message: field number to its last-seen value.
/// Supports varint and length-delimited fields; fixed64 and fixed32 fields are skipped.
/// When a field repeats, the last value wins.
public struct ProtoMessage {
    private enum Value {
        case varint(UInt64)
        case bytes([UInt8])
    }

    private var values: [Int: Value] = [:]

    /// Field numbers present in the message, in order of first appearance on the wire.
    public private(set) var fieldNumbers: [Int] = []

    public init(_ bytes: [UInt8]) throws {
        var index = 0
        while index < bytes.count {
            let tag = try Self.readVarint(bytes, at: &index)
            let field = Int(tag >> 3)
            switch tag & 7 {
            case 0:
                set(field, .varint(try Self.readVarint(bytes, at: &index)))
            case 1:
                try Self.skip(8, in: bytes, at: &index)
            case 2:
                let length = try Self.readVarint(bytes, at: &index)
                guard length <= UInt64(bytes.count - index) else { throw ProtoError.truncated }
                let end = index + Int(length)
                set(field, .bytes(Array(bytes[index..<end])))
                index = end
            case 5:
                try Self.skip(4, in: bytes, at: &index)
            case let wireType:
                throw ProtoError.unsupportedWireType(Int(wireType))
            }
        }
    }

    public func has(_ field: Int) -> Bool {
        values[field] != nil
    }

    /// The field's value if it was sent as a varint.
    public func varint(_ field: Int) -> UInt64? {
        if case .varint(let value)? = values[field] { return value }
        return nil
    }

    /// The field's payload if it was sent length-delimited.
    public func bytes(_ field: Int) -> [UInt8]? {
        if case .bytes(let value)? = values[field] { return value }
        return nil
    }

    /// The length-delimited payload decoded as UTF-8, or nil if absent or not valid UTF-8.
    public func string(_ field: Int) -> String? {
        guard let value = bytes(field) else { return nil }
        return String(bytes: value, encoding: .utf8)
    }

    /// The length-delimited payload parsed as a nested message; nil if the field is absent.
    public func message(_ field: Int) throws -> ProtoMessage? {
        guard let value = bytes(field) else { return nil }
        return try ProtoMessage(value)
    }

    private mutating func set(_ field: Int, _ value: Value) {
        if values.updateValue(value, forKey: field) == nil {
            fieldNumbers.append(field)
        }
    }

    private static func skip(_ count: Int, in bytes: [UInt8], at index: inout Int) throws {
        guard count <= bytes.count - index else { throw ProtoError.truncated }
        index += count
    }

    /// Reads one varint at `index` and advances past it.
    /// Throws `.truncated` if the input ends before the varint terminates.
    static func readVarint(_ bytes: [UInt8], at index: inout Int) throws -> UInt64 {
        var result: UInt64 = 0
        for shift in stride(from: 0, to: 70, by: 7) {
            guard index < bytes.count else { throw ProtoError.truncated }
            let byte = bytes[index]
            index += 1
            // The 10th byte may only carry the single remaining bit of a 64-bit value.
            if shift == 63 && byte > 1 { throw ProtoError.malformedVarint }
            result |= UInt64(byte & 0x7f) << UInt64(shift)
            if byte & 0x80 == 0 { return result }
        }
        throw ProtoError.malformedVarint
    }
}
