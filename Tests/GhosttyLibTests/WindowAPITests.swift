import XCTest

@testable import GhosttyLib

final class WindowAPITests: XCTestCase {
  func testCreateTerminalRequestCarriesWindowAddress() {
    let body = CreateTerminalRequest(
      location: "tab",
      command: "echo ready",
      window: "window-1",
      focus: false
    ).toBody()

    XCTAssertEqual(body["location"] as? String, "tab")
    XCTAssertEqual(body["window"] as? String, "window-1")
    XCTAssertNil(body["parent"])
    XCTAssertEqual(body["focus"] as? Bool, false)
  }

  func testCreateWindowRequestUsesWireKeyNames() {
    let body = CreateWindowRequest(
      metadata: ["role": "console", "active": true],
      findOrCreateBy: ["role": "console"],
      workingDirectory: "/tmp",
      command: "echo ready",
      env: ["MODE": "test"],
      focus: false
    ).toBody()

    XCTAssertEqual(body["metadata"] as? NSDictionary, ["role": "console", "active": true])
    XCTAssertEqual(body["find_or_create_by"] as? NSDictionary, ["role": "console"])
    XCTAssertEqual(body["working_directory"] as? String, "/tmp")
    XCTAssertEqual(body["command"] as? String, "echo ready")
    XCTAssertEqual(body["env"] as? NSDictionary, ["MODE": "test"])
    XCTAssertEqual(body["focus"] as? Bool, false)
  }

  func testWindowJSONSurfacesCreationOutcomeAndIdentity() {
    let window = Window(
      id: "window-1",
      title: "Console",
      focused: false,
      terminalIds: ["terminal-1", "terminal-2"],
      metadata: ["role": "console"]
    )
    let output = CreateWindowResult(window: window, created: false).toJsonDict()

    XCTAssertEqual(output["id"] as? String, "window-1")
    XCTAssertEqual(output["terminal_ids"] as? [String], ["terminal-1", "terminal-2"])
    XCTAssertEqual(output["created"] as? Bool, false)
  }

  func testTerminalJSONIncludesManagedWindowIdentityWhenPresent() {
    let terminal = Terminal(id: "terminal-1", windowId: "window-1", title: "shell")

    XCTAssertEqual(terminal.toJsonDict()["window_id"] as? String, "window-1")
  }

  func testWindowsAPIUnsupportedClassificationDistinguishesMissingWindow() {
    XCTAssertTrue(
      GhosttyClient.isWindowsAPIUnavailable(
        UDSResponse(status: 404, body: ["error": "not_found", "message": "Endpoint not found"]),
        collectionEndpoint: false
      )
    )
    XCTAssertTrue(
      GhosttyClient.isWindowsAPIUnavailable(
        UDSResponse(status: 404, body: ["error": "window_not_found"]),
        collectionEndpoint: true
      )
    )
    XCTAssertFalse(
      GhosttyClient.isWindowsAPIUnavailable(
        UDSResponse(
          status: 404,
          body: ["error": "window_not_found", "message": "Window not found: window-1"]
        ),
        collectionEndpoint: false
      )
    )
  }
}
