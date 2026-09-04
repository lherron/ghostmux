import XCTest

@testable import GhosttyLib

final class StatusBarSlotTests: XCTestCase {
  func testBarValueParsingAcceptsOnlyTheTwoSlots() throws {
    XCTAssertEqual(StatusBarSlot.parse("primary"), .primary)
    XCTAssertEqual(StatusBarSlot.parse("secondary"), .secondary)
    XCTAssertEqual(StatusBarSlot.parse("  SECONDARY "), .secondary)
    XCTAssertNil(StatusBarSlot.parse("tertiary"))
    XCTAssertNil(StatusBarSlot.parse(""))
  }

  func testInvalidBarValueReportsTheFlagSpecificError() {
    XCTAssertThrowsError(try StatusBarSlot.require("nope")) { error in
      XCTAssertEqual(
        String(describing: error), "--bar must be primary or secondary",
        "the error must name --bar so the user knows which flag to fix")
    }
    XCTAssertEqual(try? StatusBarSlot.require("secondary"), .secondary)
  }

  func testPrimarySlotStaysOffTheWire() {
    // Ghostty builds without the second slot never see a `bar` key for normal calls.
    XCTAssertNil(StatusBarSlot.primary.wireValue)
    XCTAssertEqual(StatusBarSlot.secondary.wireValue, "secondary")
    XCTAssertEqual(StatusBarSlot.defaultSlot, .primary)
  }

  func testUnsupportedMessageKeysOnTheWordHrcViewerMatches() {
    // hrc-viewer's isUnsupportedCommandError greps for "unsupported".
    XCTAssertTrue(StatusBarSlot.unsupportedMessage.contains("unsupported"))
  }

  func testStatusBarRequestBodyCarriesBarOnlyWhenSet() {
    let primary = GhosttyClient.statusBarRequestBody(left: "L", visible: true)
    XCTAssertNil(primary["bar"])
    XCTAssertEqual(primary["left"] as? String, "L")

    let secondary = GhosttyClient.statusBarRequestBody(
      left: "L", center: "C", right: "R", visible: true, scope: "window", bar: "secondary")
    XCTAssertEqual(secondary["bar"] as? String, "secondary")
    XCTAssertEqual(secondary["scope"] as? String, "window")
    XCTAssertEqual(secondary["visible"] as? Bool, true)
  }

  func testStatusBarQueryCarriesBarOnlyWhenSet() {
    XCTAssertEqual(GhosttyClient.statusBarQuery(), [:])
    XCTAssertEqual(GhosttyClient.statusBarQuery(scope: "window"), ["scope": "window"])
    XCTAssertEqual(
      GhosttyClient.statusBarQuery(scope: "window", bar: "secondary"),
      ["scope": "window", "bar": "secondary"])
    XCTAssertEqual(GhosttyClient.statusBarQuery(bar: "secondary"), ["bar": "secondary"])
  }

  func testStatusBarInfoDefaultsToPrimaryWhenServerOmitsBar() {
    let legacy = StatusBarInfo(
      left: "L", center: "C", right: "R", visible: true, fg: nil, bg: nil, scope: "surface")

    XCTAssertEqual(legacy.bar, "primary")
    XCTAssertEqual(legacy.toJsonDict()["bar"] as? String, "primary")
    XCTAssertFalse(
      legacy.barReportedByServer,
      "a missing bar key is the only signal that this Ghostty has no second slot")
  }

  func testStatusBarInfoReportsTheServerSuppliedSlot() {
    let modern = StatusBarInfo(
      left: "L2", center: "C2", right: "R2", visible: true, fg: nil, bg: nil, scope: "surface",
      bar: "secondary")

    XCTAssertEqual(modern.bar, "secondary")
    XCTAssertEqual(modern.toJsonDict()["bar"] as? String, "secondary")
    XCTAssertTrue(modern.barReportedByServer)
  }
}
