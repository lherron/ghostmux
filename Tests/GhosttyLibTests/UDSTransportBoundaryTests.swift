import XCTest

final class UDSTransportBoundaryTests: XCTestCase {
  func testStreamSurfaceDelegatesUDSTransportToGhosttyLib() throws {
    let repoRoot = try Self.repoRoot()
    let streamCommandURL = repoRoot.appendingPathComponent(
      "Sources/ghostmux/Commands/StreamSurfaceCommand.swift"
    )
    let streamCommand = try String(contentsOf: streamCommandURL, encoding: .utf8)
    let ghosttyClient = try String(
      contentsOf: repoRoot.appendingPathComponent("Sources/GhosttyLib/GhosttyClient.swift"),
      encoding: .utf8
    )
    let ghosttyLibURL = repoRoot.appendingPathComponent("Sources/GhosttyLib")
    let ghosttyLibFileNames = try FileManager.default.contentsOfDirectory(
      atPath: ghosttyLibURL.path
    )

    // T-05633 red bar: stream-surface may keep stdout presentation writes, but UDS socket
    // setup and framed request/event I/O must move behind a shared GhosttyLib transport.
    XCTAssertFalse(
      streamCommand.contains("private static func connectSocket"),
      "StreamSurfaceCommand must not own UDS socket setup; delegate it to GhosttyLib"
    )
    XCTAssertFalse(
      streamCommand.contains("private static func sendFrame"),
      "StreamSurfaceCommand must not own length-prefixed request framing"
    )
    XCTAssertFalse(
      streamCommand.contains("private static func readFrame"),
      "StreamSurfaceCommand must not own length-prefixed response/event framing"
    )

    let sharedTransportSource =
      ghosttyLibFileNames
      .filter { $0.hasSuffix(".swift") }
      .filter { $0 != "GhosttyClient.swift" }
      .compactMap {
        try? String(contentsOf: ghosttyLibURL.appendingPathComponent($0), encoding: .utf8)
      }
      .joined(separator: "\n")
    let hasSharedUDSTransport =
      sharedTransportSource.contains("UDSTransport")
      || sharedTransportSource.contains("FramedTransport")
      || (sharedTransportSource.contains("readFrame")
        && sharedTransportSource.contains("writeFrame"))
    XCTAssertTrue(
      hasSharedUDSTransport,
      "GhosttyLib should expose a shared UDS transport/codec outside GhosttyClient.swift"
    )

    XCTAssertTrue(
      ghosttyClient.contains("openOutputStream") || ghosttyClient.contains("openStream"),
      "GhosttyClient should provide a stream API that stream-surface can call without raw fds"
    )
    XCTAssertTrue(
      ghosttyClient.contains("invalid frame length"),
      "Normal request and stream frame reads should share the same frame-length validation error"
    )
  }

  private static func repoRoot() throws -> URL {
    var url = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    while url.path != "/" {
      if FileManager.default.fileExists(atPath: url.appendingPathComponent("Package.swift").path) {
        return url
      }
      url.deleteLastPathComponent()
    }
    throw XCTSkip("Package.swift not found from current directory")
  }
}
