import AppKit
import Darwin
import Foundation

enum GhosttyUDSFrameCodec {
  static let maxFrameLength = 10_000_000

  static func encodeFrame(_ payload: Data) throws -> Data {
    var length = UInt32(payload.count).bigEndian
    var frame = Data()
    withUnsafeBytes(of: &length) { frame.append(contentsOf: $0) }
    frame.append(payload)
    return frame
  }

  static func decodeFrameLength(_ header: Data) throws -> Int {
    guard header.count == 4 else {
      throw GhosttyError.transportRead("short response header", 0)
    }
    let lengthValue = header.reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
    let length = Int(lengthValue)
    guard length > 0 && length <= maxFrameLength else {
      throw GhosttyError.message("invalid frame length: \(length)")
    }
    return length
  }
}

public final class GhosttyUDSTransport {
  private static let scriptableGhosttyBundleId = "com.lherron.scriptableghostty"
  private static let connectRetryAttempts = 20
  private static let connectRetryDelayMicros: useconds_t = 100_000
  private static let sendRetryAttempts = 10
  private static let sendRetryDelayMicros: useconds_t = 100_000

  private let socketPath: String
  private var didEnsureScriptableGhostty = false

  public init(socketPath: String) {
    self.socketPath = socketPath
  }

  public func sendRequest(payload: Data) throws -> Data {
    var lastError: GhosttyError?
    for attempt in 0..<Self.sendRetryAttempts {
      do {
        return try sendRequestOnce(payload: payload)
      } catch let error as GhosttyError {
        lastError = error
        if shouldRetry(error), attempt < Self.sendRetryAttempts - 1 {
          usleep(Self.sendRetryDelayMicros)
          continue
        }
        throw error
      }
    }

    throw lastError ?? GhosttyError.message("failed to send request")
  }

  /// Opens a persistent framed stream using the same launch, socket-path validation, and
  /// connection retry path as one-shot requests. A live stream is intentionally not
  /// reconnected after frame I/O starts because stream events are continuous and replay
  /// semantics are not defined by ScriptableGhostty.
  public func openStream(payload: Data) throws -> GhosttyUDSStream {
    let fd = try connectSocket()
    let stream = GhosttyUDSStream(fileDescriptor: fd)
    do {
      try stream.writeFrame(payload)
      return stream
    } catch {
      stream.close()
      throw error
    }
  }

  private func sendRequestOnce(payload: Data) throws -> Data {
    let stream = try openStream(payload: payload)
    defer { stream.close() }
    return try stream.readFrameData()
  }

  private func connectSocket() throws -> Int32 {
    try ensureScriptableGhosttyRunning()

    var addr = sockaddr_un()
    addr.sun_family = sa_family_t(AF_UNIX)

    let maxLength = MemoryLayout.size(ofValue: addr.sun_path)
    guard socketPath.utf8.count < maxLength else {
      throw GhosttyError.message("socket path too long")
    }

    let nsPath = socketPath as NSString
    strncpy(&addr.sun_path.0, nsPath.fileSystemRepresentation, maxLength)

    var lastErrno: Int32 = 0
    for attempt in 0..<Self.connectRetryAttempts {
      let fd = socket(AF_UNIX, SOCK_STREAM, 0)
      if fd < 0 {
        throw GhosttyError.message("failed to create socket")
      }

      var noSigPipe: Int32 = 1
      _ = setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &noSigPipe, socklen_t(MemoryLayout<Int32>.size))

      let result = withUnsafePointer(to: &addr) { pointer in
        pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
          connect(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
        }
      }

      if result == 0 {
        return fd
      }

      lastErrno = errno
      close(fd)

      if lastErrno == ENOENT || lastErrno == ECONNREFUSED,
        attempt < Self.connectRetryAttempts - 1
      {
        usleep(Self.connectRetryDelayMicros)
        continue
      }
      break
    }

    throw GhosttyError.message("cannot connect to Ghostty UDS at \(socketPath)")
  }

  private func ensureScriptableGhosttyRunning() throws {
    if didEnsureScriptableGhostty {
      return
    }
    didEnsureScriptableGhostty = true
    if isScriptableGhosttyRunning() {
      return
    }
    try launchScriptableGhostty()
  }

  private func isScriptableGhosttyRunning() -> Bool {
    !NSRunningApplication.runningApplications(
      withBundleIdentifier: Self.scriptableGhosttyBundleId
    ).isEmpty
  }

  private func launchScriptableGhostty() throws {
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
    task.arguments = ["-g", "-b", Self.scriptableGhosttyBundleId]
    do {
      try task.run()
    } catch {
      throw GhosttyError.message("failed to launch ScriptableGhostty")
    }
    task.waitUntilExit()
    if task.terminationStatus != 0 {
      throw GhosttyError.message("failed to launch ScriptableGhostty")
    }
  }

  private func shouldRetry(_ error: GhosttyError) -> Bool {
    switch error {
    case .transportWrite(let code):
      return code == EPIPE || code == ECONNRESET || code == ENOTCONN || code == 0
    case .transportRead(_, let code):
      return code == EPIPE || code == ECONNRESET || code == ENOTCONN || code == 0
    default:
      return false
    }
  }
}

public final class GhosttyUDSStream {
  private var fileDescriptor: Int32?

  init(fileDescriptor: Int32) {
    self.fileDescriptor = fileDescriptor
  }

  deinit {
    close()
  }

  public func writeFrame(_ object: [String: Any]) throws {
    guard let json = try? JSONSerialization.data(withJSONObject: object, options: []) else {
      throw GhosttyError.message("failed to serialize request")
    }
    try writeFrame(json)
  }

  public func writeFrame(_ payload: Data) throws {
    let frame = try GhosttyUDSFrameCodec.encodeFrame(payload)
    try writeAll(data: frame)
  }

  public func readFrame() throws -> [String: Any] {
    let data = try readFrameData()
    guard let object = try? JSONSerialization.jsonObject(with: data, options: []),
      let dict = object as? [String: Any]
    else {
      throw GhosttyError.message("invalid JSON response")
    }
    return dict
  }

  public func readFrameData() throws -> Data {
    let header = try readExact(count: 4, context: "response header")
    let length = try GhosttyUDSFrameCodec.decodeFrameLength(header)
    return try readExact(count: length, context: "response body")
  }

  public func close() {
    if let fd = fileDescriptor {
      Darwin.close(fd)
      fileDescriptor = nil
    }
  }

  private func readExact(count: Int, context: String) throws -> Data {
    guard let fd = fileDescriptor else {
      throw GhosttyError.transportRead("connection closed", 0)
    }

    var buffer = [UInt8](repeating: 0, count: count)
    var offset = 0

    while offset < count {
      let result = buffer.withUnsafeMutableBytes { raw in
        let base = raw.baseAddress!.advanced(by: offset)
        return read(fd, base, count - offset)
      }
      if result == 0 {
        throw GhosttyError.transportRead("short \(context)", 0)
      }
      if result < 0 {
        if errno == EINTR {
          continue
        }
        throw GhosttyError.transportRead("short \(context)", errno)
      }
      offset += result
    }

    return Data(buffer)
  }

  private func writeAll(data: Data) throws {
    guard let fd = fileDescriptor else {
      throw GhosttyError.transportWrite(0)
    }

    var total = 0
    while total < data.count {
      let written = data.withUnsafeBytes { raw in
        let base = raw.baseAddress!.advanced(by: total)
        return write(fd, base, data.count - total)
      }
      if written < 0 {
        if errno == EINTR {
          continue
        }
        throw GhosttyError.transportWrite(errno)
      }
      if written == 0 {
        throw GhosttyError.transportWrite(0)
      }
      total += written
    }
  }
}

public struct GhosttyStreamEvent {
  public let frame: [String: Any]
  public let name: String?
  public let data: Data?

  init(frame: [String: Any]) {
    self.frame = frame
    self.name = frame["event"] as? String
    if let b64 = frame["data"] as? String {
      self.data = Data(base64Encoded: b64)
    } else {
      self.data = nil
    }
  }
}

public final class GhosttyOutputStream {
  private let stream: GhosttyUDSStream

  init(stream: GhosttyUDSStream) {
    self.stream = stream
  }

  public func readEventFrame() throws -> GhosttyStreamEvent {
    try GhosttyStreamEvent(frame: stream.readFrame())
  }

  public func close() {
    stream.close()
  }
}
