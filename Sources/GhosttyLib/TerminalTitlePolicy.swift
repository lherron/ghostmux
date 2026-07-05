import Foundation

public protocol TerminalTitleClient {
  func setTitle(terminalId: String, title: String) throws
  func sendText(terminalId: String, text: String, enter: Bool) throws
}

public enum TerminalTitleResult: Equatable {
  case endpointSuccess
  case fallbackSuccess(warning: String)
  case invalid(message: String)
  case failure(message: String)

  public var succeeded: Bool {
    switch self {
    case .endpointSuccess, .fallbackSuccess:
      return true
    case .invalid, .failure:
      return false
    }
  }

  public var resultName: String {
    switch self {
    case .endpointSuccess:
      return "endpoint"
    case .fallbackSuccess:
      return "fallback"
    case .invalid:
      return "invalid"
    case .failure:
      return "failure"
    }
  }

  public var warningMessage: String? {
    if case .fallbackSuccess(let warning) = self {
      return warning
    }
    return nil
  }

  public var errorMessage: String? {
    switch self {
    case .invalid(let message), .failure(let message):
      return message
    case .endpointSuccess, .fallbackSuccess:
      return nil
    }
  }
}

public struct TerminalTitlePolicy {
  public typealias Delay = (TimeInterval) -> Void

  public static let invalidTitleMessage = "title contains invalid characters (escape or bell)"
  public static let fallbackWarning =
    "/title endpoint unavailable; sent OSC via shell input"

  private let client: TerminalTitleClient
  private let delay: Delay

  public init(
    client: TerminalTitleClient,
    delay: @escaping Delay = TerminalTitlePolicy.sleep
  ) {
    self.client = client
    self.delay = delay
  }

  public func setTitle(
    terminalId: String,
    title: String,
    postCreateDelay: TimeInterval? = nil
  ) -> TerminalTitleResult {
    if let invalidMessage = Self.validate(title: title) {
      return .invalid(message: invalidMessage)
    }

    if let postCreateDelay, postCreateDelay > 0 {
      delay(postCreateDelay)
    }

    do {
      try client.setTitle(terminalId: terminalId, title: title)
      return .endpointSuccess
    } catch {
      guard Self.isEndpointUnavailable(error) else {
        return .failure(message: "failed to set title: \(error)")
      }

      do {
        try client.sendText(
          terminalId: terminalId,
          text: Self.oscFallbackCommand(title: title) + "\n",
          enter: false
        )
        return .fallbackSuccess(warning: Self.fallbackWarning)
      } catch {
        return .failure(message: "failed to set title via fallback: \(error)")
      }
    }
  }

  public static func validate(title: String) -> String? {
    if title.contains("\u{1b}") || title.contains("\u{07}") {
      return invalidTitleMessage
    }
    return nil
  }

  public static func isEndpointUnavailable(_ error: Error) -> Bool {
    guard case GhosttyError.apiError(let status, let message) = error else {
      return false
    }
    return status == 404 || (message?.contains("Endpoint not found") ?? false)
  }

  public static func oscFallbackCommand(title: String) -> String {
    let escaped =
      title
      .replacingOccurrences(of: "\\", with: "\\\\")
      .replacingOccurrences(of: "'", with: "\\'")
    return "printf $'\\e]0;\(escaped)\\a'"
  }

  public static func sleep(_ seconds: TimeInterval) {
    usleep(UInt32(seconds * 1_000_000))
  }
}
