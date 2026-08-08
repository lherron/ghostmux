import Foundation

public final class GhosttyClient {
  private let _socketPath: String
  private let transport: GhosttyUDSTransport

  /// The path to the UDS socket
  public var socketPath: String { _socketPath }

  public init(socketPath: String) {
    self._socketPath = socketPath
    self.transport = GhosttyUDSTransport(socketPath: socketPath)
  }

  public func listTerminals() throws -> [Terminal] {
    let response = try request(version: "v2", method: "GET", path: "/terminals")
    guard response.status == 200 else {
      throw GhosttyError.apiError(response.status, response.bodyError)
    }
    guard let body = response.body,
      let terminals = body["terminals"] as? [[String: Any]]
    else {
      return []
    }
    return terminals.compactMap(parseTerminal)
  }

  public func listWindows(metadataFilters: [String: String] = [:]) throws -> [Window] {
    let query = Dictionary(
      uniqueKeysWithValues: metadataFilters.map { ("meta.\($0.key)", $0.value) })
    let response = try request(version: "v2", method: "GET", path: "/windows", query: query)
    try checkWindowsResponse(response, collectionEndpoint: true)
    guard let body = response.body,
      let windows = body["windows"] as? [[String: Any]]
    else {
      return []
    }
    return windows.compactMap(parseWindow)
  }

  public func getWindow(windowId: String) throws -> Window {
    let response = try request(version: "v2", method: "GET", path: "/windows/\(windowId)")
    try checkWindowsResponse(response)
    guard let body = response.body, let window = parseWindow(body) else {
      throw GhosttyError.message("invalid window response")
    }
    return window
  }

  public func createWindow(request: CreateWindowRequest) throws -> CreateWindowResult {
    let body = request.toBody()
    guard JSONSerialization.isValidJSONObject(body) else {
      throw GhosttyError.message("window metadata must contain valid JSON values")
    }
    let response = try self.request(
      version: "v2",
      method: "POST",
      path: "/windows",
      body: body
    )
    try checkWindowsResponse(response, collectionEndpoint: true)
    guard let body = response.body,
      let window = parseWindow(body),
      let created = body["created"] as? Bool
    else {
      throw GhosttyError.message("invalid create window response")
    }
    return CreateWindowResult(window: window, created: created)
  }

  public func createTerminal(request: CreateTerminalRequest) throws -> Terminal {
    if let windowId = request.window {
      _ = try getWindow(windowId: windowId)
    }
    let response = try self.request(
      version: "v2",
      method: "POST",
      path: "/terminals",
      body: request.toBody()
    )
    guard response.status == 200 else {
      throw GhosttyError.apiError(response.status, response.bodyError)
    }
    guard let body = response.body, let terminal = parseTerminal(body) else {
      throw GhosttyError.message("invalid create terminal response")
    }
    return terminal
  }

  public func deleteTerminal(terminalId: String, confirm: Bool) throws {
    let query = confirm ? ["confirm": "true"] : [:]
    let response = try request(
      version: "v2",
      method: "DELETE",
      path: "/terminals/\(terminalId)",
      query: query
    )
    guard response.status == 200 else {
      throw GhosttyError.apiError(response.status, response.bodyError)
    }
    if let success = response.body?["success"] as? Bool, !success {
      throw GhosttyError.message("kill-surface failed")
    }
  }

  public func isAvailable() -> Bool {
    do {
      let response = try request(version: "v2", method: "GET", path: "/terminals")
      return response.status == 200
    } catch {
      return false
    }
  }

  public func sendKey(terminalId: String, stroke: KeyStroke) throws {
    var body: [String: Any] = [
      "key": stroke.key,
      "unshifted_codepoint": stroke.unshiftedCodepoint,
    ]
    if let text = stroke.text {
      body["text"] = text
    }
    if !stroke.mods.isEmpty {
      body["mods"] = stroke.mods
    }
    let response = try request(
      version: "v2", method: "POST", path: "/terminals/\(terminalId)/key", body: body)
    guard response.status == 200 else {
      throw GhosttyError.apiError(response.status, response.bodyError)
    }
    if let success = response.body?["success"] as? Bool, !success {
      throw GhosttyError.message("send-keys failed")
    }
  }

  public func sendText(terminalId: String, text: String, enter: Bool = false) throws {
    var body: [String: Any] = ["text": text]
    if enter {
      body["enter"] = true
    }
    let response = try request(
      version: "v2", method: "POST", path: "/terminals/\(terminalId)/input", body: body)
    guard response.status == 200 else {
      throw GhosttyError.apiError(response.status, response.bodyError)
    }
    if let success = response.body?["success"] as? Bool, !success {
      throw GhosttyError.message("input failed")
    }
  }

  public func sendOutput(terminalId: String, data: String) throws {
    let body: [String: Any] = ["data": data]
    let response = try request(
      version: "v2", method: "POST", path: "/terminals/\(terminalId)/output", body: body)
    guard response.status == 200 else {
      throw GhosttyError.apiError(response.status, response.bodyError)
    }
    if let success = response.body?["success"] as? Bool, !success {
      throw GhosttyError.message("output failed")
    }
  }

  public func setTitle(terminalId: String, title: String) throws {
    let body: [String: Any] = ["title": title]
    let response = try request(
      version: "v2", method: "POST", path: "/terminals/\(terminalId)/title", body: body)
    guard response.status == 200 else {
      throw GhosttyError.apiError(response.status, response.bodyError)
    }
    if let success = response.body?["success"] as? Bool, !success {
      throw GhosttyError.message("set-title failed")
    }
  }

  public func setStatusBar(
    terminalId: String,
    left: String? = nil,
    center: String? = nil,
    right: String? = nil,
    visible: Bool? = nil,
    toggle: Bool? = nil,
    scope: String? = nil,
    fg: String? = nil,
    bg: String? = nil
  ) throws {
    var body: [String: Any] = [:]
    if let left { body["left"] = left }
    if let center { body["center"] = center }
    if let right { body["right"] = right }
    if let visible { body["visible"] = visible }
    if let toggle { body["toggle"] = toggle }
    if let scope { body["scope"] = scope }
    if let fg { body["fg"] = fg }
    if let bg { body["bg"] = bg }
    if body.isEmpty {
      throw GhosttyError.message("statusbar update requires at least one field")
    }

    let response = try request(
      version: "v2",
      method: "POST",
      path: "/terminals/\(terminalId)/statusbar",
      body: body
    )
    guard response.status == 200 else {
      throw GhosttyError.apiError(response.status, response.bodyError)
    }
    if let success = response.body?["success"] as? Bool, !success {
      throw GhosttyError.message("statusbar update failed")
    }
  }

  public func getStatusBar(
    terminalId: String,
    scope: String? = nil
  ) throws -> StatusBarInfo {
    var query: [String: String] = [:]
    if let scope { query["scope"] = scope }

    let response = try request(
      version: "v2",
      method: "GET",
      path: "/terminals/\(terminalId)/statusbar",
      query: query
    )
    guard response.status == 200 else {
      throw GhosttyError.apiError(response.status, response.bodyError)
    }
    guard let body = response.body else {
      throw GhosttyError.message("invalid statusbar response")
    }
    return StatusBarInfo(
      left: body["left"] as? String ?? "",
      center: body["center"] as? String ?? "",
      right: body["right"] as? String ?? "",
      visible: body["visible"] as? Bool ?? false,
      fg: body["fg"] as? String,
      bg: body["bg"] as? String,
      scope: body["scope"] as? String ?? "surface"
    )
  }

  public func getMetadata(
    terminalId: String,
    scope: String? = nil,
    resolved: Bool? = nil
  ) throws -> [String: Any] {
    var query: [String: String] = [:]
    if let scope { query["scope"] = scope }
    if let resolved { query["resolved"] = resolved ? "true" : "false" }

    let response = try request(
      version: "v2",
      method: "GET",
      path: "/terminals/\(terminalId)/metadata",
      query: query
    )
    guard response.status == 200 else {
      throw GhosttyError.apiError(response.status, response.bodyError)
    }
    return response.body?["data"] as? [String: Any] ?? [:]
  }

  public func mergeMetadata(
    terminalId: String,
    data: [String: Any],
    scope: String? = nil,
    method: String = "PATCH"
  ) throws -> [String: Any] {
    let verb = method.uppercased()
    guard verb == "PATCH" || verb == "POST" else {
      throw GhosttyError.message("metadata merge supports PATCH or POST")
    }
    guard JSONSerialization.isValidJSONObject(data) else {
      throw GhosttyError.message("metadata values must be valid JSON")
    }

    var body: [String: Any] = ["data": data]
    if let scope { body["scope"] = scope }

    let response = try request(
      version: "v2",
      method: verb,
      path: "/terminals/\(terminalId)/metadata",
      body: body
    )
    guard response.status == 200 else {
      throw GhosttyError.apiError(response.status, response.bodyError)
    }
    return response.body?["data"] as? [String: Any] ?? [:]
  }

  public func replaceMetadata(
    terminalId: String,
    data: [String: Any],
    scope: String? = nil
  ) throws -> [String: Any] {
    guard JSONSerialization.isValidJSONObject(data) else {
      throw GhosttyError.message("metadata values must be valid JSON")
    }

    var body: [String: Any] = ["data": data]
    if let scope { body["scope"] = scope }

    let response = try request(
      version: "v2",
      method: "PUT",
      path: "/terminals/\(terminalId)/metadata",
      body: body
    )
    guard response.status == 200 else {
      throw GhosttyError.apiError(response.status, response.bodyError)
    }
    return response.body?["data"] as? [String: Any] ?? [:]
  }

  public func deleteMetadata(
    terminalId: String,
    scope: String? = nil
  ) throws -> [String: Any] {
    var query: [String: String] = [:]
    if let scope { query["scope"] = scope }

    let response = try request(
      version: "v2",
      method: "DELETE",
      path: "/terminals/\(terminalId)/metadata",
      query: query
    )
    guard response.status == 200 else {
      throw GhosttyError.apiError(response.status, response.bodyError)
    }
    return response.body?["data"] as? [String: Any] ?? [:]
  }

  public func getWindowMetadata(windowId: String) throws -> [String: Any] {
    let response = try request(
      version: "v2",
      method: "GET",
      path: "/windows/\(windowId)/metadata"
    )
    try checkWindowsResponse(response)
    return response.body?["data"] as? [String: Any] ?? [:]
  }

  public func mergeWindowMetadata(
    windowId: String,
    data: [String: Any]
  ) throws -> [String: Any] {
    guard JSONSerialization.isValidJSONObject(data) else {
      throw GhosttyError.message("metadata values must be valid JSON")
    }
    let response = try request(
      version: "v2",
      method: "PATCH",
      path: "/windows/\(windowId)/metadata",
      body: ["data": data]
    )
    try checkWindowsResponse(response)
    return response.body?["data"] as? [String: Any] ?? [:]
  }

  public func replaceWindowMetadata(
    windowId: String,
    data: [String: Any]
  ) throws -> [String: Any] {
    guard JSONSerialization.isValidJSONObject(data) else {
      throw GhosttyError.message("metadata values must be valid JSON")
    }
    let response = try request(
      version: "v2",
      method: "PUT",
      path: "/windows/\(windowId)/metadata",
      body: ["data": data]
    )
    try checkWindowsResponse(response)
    return response.body?["data"] as? [String: Any] ?? [:]
  }

  public func deleteWindowMetadata(windowId: String) throws -> [String: Any] {
    let response = try request(
      version: "v2",
      method: "DELETE",
      path: "/windows/\(windowId)/metadata"
    )
    try checkWindowsResponse(response)
    return response.body?["data"] as? [String: Any] ?? [:]
  }

  public func getScreenContents(terminalId: String) throws -> String {
    let response = try request(
      version: "v2", method: "GET", path: "/terminals/\(terminalId)/screen")
    guard response.status == 200 else {
      throw GhosttyError.apiError(response.status, response.bodyError)
    }
    return response.body?["contents"] as? String ?? ""
  }

  public func getVisibleContents(terminalId: String) throws -> String {
    let response = try request(
      version: "v2", method: "GET", path: "/terminals/\(terminalId)/details/visible")
    guard response.status == 200 else {
      throw GhosttyError.apiError(response.status, response.bodyError)
    }
    return response.body?["value"] as? String ?? ""
  }

  public func getSelectionContents(terminalId: String) throws -> String? {
    let response = try request(
      version: "v2", method: "GET", path: "/terminals/\(terminalId)/details/selection")
    guard response.status == 200 else {
      throw GhosttyError.apiError(response.status, response.bodyError)
    }
    return response.body?["value"] as? String
  }

  public func getScreenshot(terminalId: String) throws -> TerminalScreenshot {
    let response = try request(
      version: "v2", method: "GET", path: "/terminals/\(terminalId)/screenshot")
    guard response.status == 200 else {
      throw GhosttyError.apiError(response.status, response.bodyError)
    }
    guard let body = response.body else {
      throw GhosttyError.message("invalid screenshot response")
    }
    guard let encoded = body["data"] as? String,
      let data = Data(base64Encoded: encoded)
    else {
      throw GhosttyError.message("invalid screenshot data")
    }

    return TerminalScreenshot(
      id: body["id"] as? String ?? terminalId,
      mimeType: body["mime_type"] as? String ?? "image/png",
      width: body["width"] as? Int ?? 0,
      height: body["height"] as? Int ?? 0,
      data: data
    )
  }

  public func getTerminal(terminalId: String) throws -> Terminal {
    let response = try request(version: "v2", method: "GET", path: "/terminals/\(terminalId)")
    guard response.status == 200 else {
      throw GhosttyError.apiError(response.status, response.bodyError)
    }
    guard let body = response.body, let terminal = parseTerminal(body) else {
      throw GhosttyError.message("terminal not found")
    }
    return terminal
  }

  public func executeAction(terminalId: String, action: String) throws {
    let body: [String: Any] = ["action": action]
    let response = try request(
      version: "v2", method: "POST", path: "/terminals/\(terminalId)/action", body: body)
    guard response.status == 200 else {
      throw GhosttyError.apiError(response.status, response.bodyError)
    }
    if let success = response.body?["success"] as? Bool, !success {
      let errorMsg = response.body?["error"] as? String ?? "action failed"
      throw GhosttyError.message(errorMsg)
    }
  }

  public func focusTerminal(terminalId: String) throws {
    let response = try request(
      version: "v2", method: "POST", path: "/terminals/\(terminalId)/focus")
    guard response.status == 200 else {
      throw GhosttyError.apiError(response.status, response.bodyError)
    }
  }

  public func openOutputStream(terminalId: String) throws -> GhosttyOutputStream {
    let envelope: [String: Any] = [
      "version": "v2",
      "method": "GET",
      "path": "/terminals/\(terminalId)/stream",
    ]
    let payload = try JSONSerialization.data(withJSONObject: envelope, options: [])
    let stream = try transport.openStream(payload: payload)
    do {
      // The transport owns the shared "invalid frame length" validation for both
      // ordinary responses and stream frames.
      let initialResponse = try UDSResponse.decode(stream.readFrameData())
      guard initialResponse.status == 200 else {
        throw GhosttyError.apiError(initialResponse.status, initialResponse.bodyError)
      }
      return GhosttyOutputStream(stream: stream)
    } catch {
      stream.close()
      throw error
    }
  }

  private func request(
    version: String,
    method: String,
    path: String,
    query: [String: String] = [:],
    body: [String: Any]? = nil
  ) throws -> UDSResponse {
    var envelope: [String: Any] = [
      "version": version,
      "method": method,
      "path": path,
    ]
    if !query.isEmpty {
      envelope["query"] = query
    }
    if let body {
      envelope["body"] = body
    }

    let payload = try JSONSerialization.data(withJSONObject: envelope, options: [])
    let responseData = try transport.sendRequest(payload: payload)
    return try UDSResponse.decode(responseData)
  }

  private func parseTerminal(_ dict: [String: Any]) -> Terminal? {
    guard let id = dict["id"] as? String,
      let title = dict["title"] as? String
    else {
      return nil
    }

    return Terminal(
      id: id,
      windowId: dict["window_id"] as? String,
      title: title,
      workingDirectory: dict["working_directory"] as? String,
      focused: dict["focused"] as? Bool ?? false,
      columns: dict["columns"] as? Int,
      rows: dict["rows"] as? Int,
      cellWidth: dict["cell_width"] as? Int,
      cellHeight: dict["cell_height"] as? Int
    )
  }

  private func parseWindow(_ dict: [String: Any]) -> Window? {
    guard let id = dict["id"] as? String,
      let title = dict["title"] as? String,
      let terminalIds = dict["terminal_ids"] as? [String]
    else {
      return nil
    }

    return Window(
      id: id,
      title: title,
      focused: dict["focused"] as? Bool ?? false,
      terminalIds: terminalIds,
      metadata: dict["metadata"] as? [String: Any] ?? [:]
    )
  }

  private func checkWindowsResponse(
    _ response: UDSResponse,
    collectionEndpoint: Bool = false
  ) throws {
    guard response.status == 200 else {
      if Self.isWindowsAPIUnavailable(response, collectionEndpoint: collectionEndpoint) {
        throw GhosttyError.message(
          "server does not support the windows API; update ScriptableGhostty")
      }
      throw GhosttyError.apiError(response.status, response.bodyError)
    }
  }

  static func isWindowsAPIUnavailable(
    _ response: UDSResponse,
    collectionEndpoint: Bool
  ) -> Bool {
    guard response.status == 404 else { return false }
    if collectionEndpoint { return true }
    if response.body?["error"] as? String == "not_found" { return true }
    return response.bodyError?.contains("Endpoint not found") ?? false
  }

}

public struct UDSResponse {
  public let status: Int
  public let body: [String: Any]?

  public var bodyError: String? {
    if let body, let message = body["message"] as? String {
      return message
    }
    if let body, let error = body["error"] as? String {
      return error
    }
    return nil
  }

  public static func decode(_ data: Data) throws -> UDSResponse {
    let object = try JSONSerialization.jsonObject(with: data, options: [])
    guard let dict = object as? [String: Any] else {
      throw GhosttyError.message("invalid response")
    }
    let status = dict["status"] as? Int ?? 500
    let body = dict["body"] as? [String: Any]
    return UDSResponse(status: status, body: body)
  }
}

extension GhosttyClient: TerminalTitleClient {}

public enum GhosttyError: Error, CustomStringConvertible {
  case message(String)
  case apiError(Int, String?)
  case transportWrite(Int32)
  case transportRead(String, Int32)

  public var description: String {
    switch self {
    case .message(let message):
      return message
    case .apiError(let status, let message):
      if let message {
        return message
      }
      return "API error (HTTP \(status))"
    case .transportWrite:
      return "failed to write request"
    case .transportRead(let message, _):
      return message
    }
  }
}
