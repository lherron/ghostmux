import XCTest
@testable import GhosttyLib

final class TerminalTitlePolicyTests: XCTestCase {
  func testRejectsEscapeAndBellBeforeClientCalls() {
    let client = RecordingTitleClient()
    let policy = TerminalTitlePolicy(client: client)

    XCTAssertEqual(
      policy.setTitle(terminalId: "term-1", title: "bad\u{1b}title"),
      .invalid(message: TerminalTitlePolicy.invalidTitleMessage)
    )
    XCTAssertEqual(
      policy.setTitle(terminalId: "term-1", title: "bad\u{07}title"),
      .invalid(message: TerminalTitlePolicy.invalidTitleMessage)
    )
    XCTAssertEqual(client.setTitleCalls.count, 0)
    XCTAssertEqual(client.sendTextCalls.count, 0)
  }

  func testEndpointSuccessDoesNotFallback() {
    let client = RecordingTitleClient()
    let policy = TerminalTitlePolicy(client: client)

    XCTAssertEqual(policy.setTitle(terminalId: "term-1", title: "build"), .endpointSuccess)
    XCTAssertEqual(client.setTitleCalls.map(\.title), ["build"])
    XCTAssertEqual(client.sendTextCalls.count, 0)
  }

  func testEndpointUnavailableFallsBackToOscInput() {
    let client = RecordingTitleClient()
    client.setTitleError = GhosttyError.apiError(404, nil)
    let policy = TerminalTitlePolicy(client: client)

    XCTAssertEqual(
      policy.setTitle(terminalId: "term-1", title: "fallback"),
      .fallbackSuccess(warning: TerminalTitlePolicy.fallbackWarning)
    )
    XCTAssertEqual(client.sendTextCalls.count, 1)
    XCTAssertEqual(client.sendTextCalls[0].terminalId, "term-1")
    XCTAssertEqual(client.sendTextCalls[0].text, "printf $'\\e]0;fallback\\a'\n")
    XCTAssertFalse(client.sendTextCalls[0].enter)
  }

  func testEndpointUnavailableMessageFallsBack() {
    XCTAssertTrue(
      TerminalTitlePolicy.isEndpointUnavailable(
        GhosttyError.apiError(500, "Endpoint not found: /terminals/id/title")
      )
    )
  }

  func testHardFailureDoesNotFallback() {
    let client = RecordingTitleClient()
    client.setTitleError = GhosttyError.apiError(500, "boom")
    let policy = TerminalTitlePolicy(client: client)

    let result = policy.setTitle(terminalId: "term-1", title: "build")
    XCTAssertEqual(result.resultName, "failure")
    XCTAssertEqual(client.sendTextCalls.count, 0)
    XCTAssertEqual(result.errorMessage, "failed to set title: boom")
  }

  func testFallbackFailureReportsHardFailure() {
    let client = RecordingTitleClient()
    client.setTitleError = GhosttyError.apiError(404, nil)
    client.sendTextError = GhosttyError.message("input failed")
    let policy = TerminalTitlePolicy(client: client)

    let result = policy.setTitle(terminalId: "term-1", title: "build")
    XCTAssertEqual(result.resultName, "failure")
    XCTAssertEqual(result.errorMessage, "failed to set title via fallback: input failed")
  }

  func testOscFallbackEscapesBackslashAndSingleQuote() {
    XCTAssertEqual(
      TerminalTitlePolicy.oscFallbackCommand(title: #"a\b'c"#),
      #"printf $'\e]0;a\\b\'c\a'"#
    )
  }

  func testPostCreateDelayIsInjectable() {
    let client = RecordingTitleClient()
    var delays: [TimeInterval] = []
    let policy = TerminalTitlePolicy(
      client: client,
      delay: { delays.append($0) }
    )

    XCTAssertEqual(
      policy.setTitle(terminalId: "term-1", title: "build", postCreateDelay: 1.0),
      .endpointSuccess
    )
    XCTAssertEqual(delays, [1.0])
  }
}

private final class RecordingTitleClient: TerminalTitleClient {
  var setTitleError: Error?
  var sendTextError: Error?
  var setTitleCalls: [(terminalId: String, title: String)] = []
  var sendTextCalls: [(terminalId: String, text: String, enter: Bool)] = []

  func setTitle(terminalId: String, title: String) throws {
    setTitleCalls.append((terminalId: terminalId, title: title))
    if let setTitleError {
      throw setTitleError
    }
  }

  func sendText(terminalId: String, text: String, enter: Bool) throws {
    sendTextCalls.append((terminalId: terminalId, text: text, enter: enter))
    if let sendTextError {
      throw sendTextError
    }
  }
}
