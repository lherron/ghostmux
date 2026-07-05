import Darwin
import Foundation
import XCTest

@testable import GhosttyLib

final class GhosttyUDSTransportTests: XCTestCase {
  func testFrameCodecRoundTripsLengthPrefix() throws {
    let payload = Data("{\"ok\":true}".utf8)
    let frame = try GhosttyUDSFrameCodec.encodeFrame(payload)

    XCTAssertEqual(try GhosttyUDSFrameCodec.decodeFrameLength(frame.prefix(4)), payload.count)
    XCTAssertEqual(frame.dropFirst(4), payload)
  }

  func testFrameCodecRejectsZeroAndOversizedLengths() {
    XCTAssertThrowsError(try GhosttyUDSFrameCodec.decodeFrameLength(Data([0, 0, 0, 0]))) { error in
      XCTAssertEqual(String(describing: error), "invalid frame length: 0")
    }

    let oversized = UInt32(GhosttyUDSFrameCodec.maxFrameLength + 1)
    let header = Data([
      UInt8((oversized >> 24) & 0xff),
      UInt8((oversized >> 16) & 0xff),
      UInt8((oversized >> 8) & 0xff),
      UInt8(oversized & 0xff),
    ])
    XCTAssertThrowsError(try GhosttyUDSFrameCodec.decodeFrameLength(header)) { error in
      XCTAssertEqual(
        String(describing: error),
        "invalid frame length: \(GhosttyUDSFrameCodec.maxFrameLength + 1)"
      )
    }
  }

  func testStreamReadsDictionaryFramesThroughSharedCodec() throws {
    var sockets = [Int32](repeating: -1, count: 2)
    XCTAssertEqual(socketpair(AF_UNIX, SOCK_STREAM, 0, &sockets), 0)

    let writer = GhosttyUDSStream(fileDescriptor: sockets[0])
    let reader = GhosttyUDSStream(fileDescriptor: sockets[1])
    defer {
      writer.close()
      reader.close()
    }

    try writer.writeFrame(["event": "output", "data": "aGVsbG8="])

    let frame = try reader.readFrame()
    XCTAssertEqual(frame["event"] as? String, "output")
    XCTAssertEqual(frame["data"] as? String, "aGVsbG8=")
  }

  func testStreamRejectsInvalidJSONResponse() throws {
    var sockets = [Int32](repeating: -1, count: 2)
    XCTAssertEqual(socketpair(AF_UNIX, SOCK_STREAM, 0, &sockets), 0)

    let writer = GhosttyUDSStream(fileDescriptor: sockets[0])
    let reader = GhosttyUDSStream(fileDescriptor: sockets[1])
    defer {
      writer.close()
      reader.close()
    }

    try writer.writeFrame(Data("not json".utf8))

    XCTAssertThrowsError(try reader.readFrame()) { error in
      XCTAssertEqual(String(describing: error), "invalid JSON response")
    }
  }
}
