import XCTest
import TVRemoteKit

final class ProtoTests: XCTestCase {
    // MARK: Writer

    func testWriterEncodesKeyInject() {
        var w = ProtoWriter()
        w.message(10) { $0.varint(1, 19); $0.varint(2, 3) }
        XCTAssertEqual(w.bytes.hex, "520408131003")
    }

    func testWriterEncodesPingResponse() {
        var w = ProtoWriter()
        w.message(9) { $0.varint(1, 5) }
        XCTAssertEqual(w.bytes.hex, "4a020805")
    }

    func testWriterEncodesMultiByteFieldTag() {
        var w = ProtoWriter()
        w.message(90) { $0.string(1, "https://www.youtube.com") }
        XCTAssertEqual(w.bytes.hex, "d205190a1768747470733a2f2f7777772e796f75747562652e636f6d")
    }

    func testWriterEncodesBoolAndBytes() {
        var w = ProtoWriter()
        w.bool(1, true)
        w.bool(2, false)
        w.bytes(3, [0xde, 0xad])
        XCTAssertEqual(w.bytes.hex, "08011000" + "1a02dead")
    }

    func testWriterEncodesLargeVarint() {
        var w = ProtoWriter()
        w.varint(1, 300)
        w.varint(2, UInt64.max)
        XCTAssertEqual(w.bytes.hex, "08ac02" + "10ffffffffffffffffff01")
    }

    func testWriterEncodesEmptyMessage() {
        var w = ProtoWriter()
        w.message(2) { _ in }
        XCTAssertEqual(w.bytes.hex, "1200")
    }

    // MARK: Reader

    func testReaderParsesVolume() throws {
        let m = try ProtoMessage(Array(hex: "92030b1a0354434c3064380c4000")).message(50)!
        XCTAssertEqual(m.varint(6), 100)
        XCTAssertEqual(m.varint(7), 12)
        XCTAssertEqual(m.varint(8), 0)
        XCTAssertEqual(m.string(3), "TCL")
    }

    func testReaderRejectsTruncated() {
        XCTAssertThrowsError(try ProtoMessage(Array(hex: "5204081310"))) { error in
            XCTAssertEqual(error as? ProtoError, .truncated)
        }
    }

    func testReaderRejectsTruncatedVarint() {
        XCTAssertThrowsError(try ProtoMessage(Array(hex: "08ac"))) { error in
            XCTAssertEqual(error as? ProtoError, .truncated)
        }
    }

    func testReaderRejectsOverlongVarint() {
        // Eleven continuation bytes never terminate within the 10-byte varint limit.
        XCTAssertThrowsError(try ProtoMessage(Array(hex: "08" + String(repeating: "80", count: 11) + "01"))) { error in
            XCTAssertEqual(error as? ProtoError, .malformedVarint)
        }
    }

    func testReaderRejectsGroupWireType() {
        // 0x0b = field 1, wire type 3 (start group)
        XCTAssertThrowsError(try ProtoMessage(Array(hex: "0b"))) { error in
            XCTAssertEqual(error as? ProtoError, .unsupportedWireType(3))
        }
    }

    func testReaderSkipsFixed64AndFixed32() throws {
        // field 1: fixed64 (wire 1), field 2: fixed32 (wire 5), field 3: varint 7
        let m = try ProtoMessage(Array(hex: "09" + "0102030405060708" + "15" + "01020304" + "1807"))
        XCTAssertEqual(m.varint(3), 7)
        XCTAssertFalse(m.has(1))
        XCTAssertFalse(m.has(2))
        XCTAssertEqual(m.fieldNumbers, [3])
    }

    func testReaderRejectsTruncatedFixed() {
        XCTAssertThrowsError(try ProtoMessage(Array(hex: "090102"))) { error in
            XCTAssertEqual(error as? ProtoError, .truncated)
        }
    }

    func testReaderLastValueWinsForRepeatedScalars() throws {
        let m = try ProtoMessage(Array(hex: "0801" + "0802" + "0803"))
        XCTAssertEqual(m.varint(1), 3)
        XCTAssertEqual(m.fieldNumbers, [1])
    }

    func testReaderHasAndWireTypeMismatch() throws {
        let m = try ProtoMessage(Array(hex: "0805" + "120161"))
        XCTAssertTrue(m.has(1))
        XCTAssertTrue(m.has(2))
        XCTAssertFalse(m.has(3))
        XCTAssertNil(m.varint(2))
        XCTAssertNil(m.bytes(1))
        XCTAssertNil(m.string(1))
        XCTAssertNil(m.varint(3))
        XCTAssertEqual(m.bytes(2), [0x61])
        XCTAssertEqual(m.string(2), "a")
        XCTAssertEqual(m.fieldNumbers, [1, 2])
    }

    func testReaderMessageIsNilWhenAbsentAndThrowsWhenMalformed() throws {
        let absent = try ProtoMessage(Array(hex: "0801"))
        XCTAssertNil(try absent.message(2))
        // field 2 holds bytes that are not a valid message (truncated nested varint)
        let bad = try ProtoMessage(Array(hex: "120108"))
        XCTAssertThrowsError(try bad.message(2)) { error in
            XCTAssertEqual(error as? ProtoError, .truncated)
        }
    }

    func testReaderRoundTripsWriter() throws {
        var w = ProtoWriter()
        w.varint(1, 42)
        w.string(2, "héllo")
        w.message(3) { $0.bool(1, true); $0.bytes(2, [1, 2, 3]) }
        let m = try ProtoMessage(w.bytes)
        XCTAssertEqual(m.varint(1), 42)
        XCTAssertEqual(m.string(2), "héllo")
        let inner = try XCTUnwrap(m.message(3))
        XCTAssertEqual(inner.varint(1), 1)
        XCTAssertEqual(inner.bytes(2), [1, 2, 3])
        XCTAssertEqual(m.fieldNumbers, [1, 2, 3])
    }
}
