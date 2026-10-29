import XCTest
import TVRemoteKit

final class FramingTests: XCTestCase {
    private let frameA = Array(hex: "520408131003")
    private let frameB = Array(hex: "4a020805")

    func testFrameAddsVarintLength() {
        XCTAssertEqual(Framing.frame(Array(hex: "520408131003")).hex, "06520408131003")
    }

    func testFrameOfEmptyPayloadIsSingleZeroByte() {
        XCTAssertEqual(Framing.frame([]).hex, "00")
    }

    func testDecoderHandlesByteByByte() throws {
        let stream = Framing.frame(frameA) + Framing.frame(frameB)
        let endOfA = Framing.frame(frameA).count - 1
        var decoder = FrameDecoder()
        for (index, byte) in stream.enumerated() {
            decoder.append([byte])
            let payload = try decoder.next()
            switch index {
            case endOfA: XCTAssertEqual(payload, frameA)
            case stream.count - 1: XCTAssertEqual(payload, frameB)
            default: XCTAssertNil(payload, "no frame should be ready after byte \(index)")
            }
        }
        XCTAssertNil(try decoder.next())
    }

    func testDecoderHandlesTwoFramesInOneChunk() throws {
        var decoder = FrameDecoder()
        decoder.append(Framing.frame(frameA) + Framing.frame(frameB))
        XCTAssertEqual(try decoder.next(), frameA)
        XCTAssertEqual(try decoder.next(), frameB)
        XCTAssertNil(try decoder.next())
    }

    func testDecoderKeepsPartialFrameAcrossAppends() throws {
        var decoder = FrameDecoder()
        let whole = Framing.frame(frameA) + Framing.frame(frameB)
        decoder.append(Array(whole[0..<9]))   // all of A plus the first 2 bytes of B
        XCTAssertEqual(try decoder.next(), frameA)
        XCTAssertNil(try decoder.next())
        decoder.append(Array(whole[9...]))
        XCTAssertEqual(try decoder.next(), frameB)
        XCTAssertNil(try decoder.next())
    }

    func testDecoderHandles300ByteFrame() throws {
        let payload = (0..<300).map { UInt8($0 % 251) }
        let framed = Framing.frame(payload)
        XCTAssertEqual(Array(framed.prefix(2)).hex, "ac02")
        var decoder = FrameDecoder()
        decoder.append(framed)
        XCTAssertEqual(try decoder.next(), payload)
        XCTAssertNil(try decoder.next())
    }

    func testDecoderReturnsEmptyPayloadForZeroLengthFrame() throws {
        var decoder = FrameDecoder()
        decoder.append([0x00])
        XCTAssertEqual(try decoder.next(), [])
        XCTAssertNil(try decoder.next())
    }

    func testDecoderRejectsHugeFrame() {
        var decoder = FrameDecoder()
        decoder.append(Array(hex: "818040"))   // varint 1_048_577 = 1 MiB + 1
        XCTAssertThrowsError(try decoder.next()) { error in
            XCTAssertEqual(error as? ProtoError, .frameTooLarge)
        }
    }

    func testDecoderAcceptsFrameOfExactlyOneMiB() throws {
        var decoder = FrameDecoder()
        decoder.append(Array(hex: "808040"))   // varint 1_048_576 = 1 MiB, payload not yet received
        XCTAssertNil(try decoder.next())
    }

    func testDecoderRejectsMalformedLengthVarint() {
        var decoder = FrameDecoder()
        decoder.append(Array(repeating: 0x80, count: 11))
        XCTAssertThrowsError(try decoder.next()) { error in
            XCTAssertEqual(error as? ProtoError, .malformedVarint)
        }
    }
}
