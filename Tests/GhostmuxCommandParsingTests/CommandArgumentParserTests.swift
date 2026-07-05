import XCTest
@testable import GhostmuxCommandParsing

final class CommandArgumentParserTests: XCTestCase {
  func testCommonFlagsTargetAliasesAndOrderedPositionalsArePreserved() throws {
    let parser = CommandArgumentParser(
      targetFlags: ["-t", "--target"],
      allowsPositionals: true,
      repeatedTarget: .lastWins
    )

    let result = try parser.parse(["--json", "--target", "surface-1", "metadata", "get", "title"])

    XCTAssertFalse(result.help)
    XCTAssertTrue(result.json)
    XCTAssertEqual(result.target, "surface-1")
    XCTAssertEqual(result.positionals, ["metadata", "get", "title"])
  }

  func testHelpFlagShortCircuitsWithoutTreatingLaterTokensAsUnexpected() throws {
    let parser = CommandArgumentParser(
      targetFlags: ["-t"],
      allowsPositionals: false,
      repeatedTarget: .lastWins
    )

    let result = try parser.parse(["--help", "--definitely-not-a-real-flag"])

    XCTAssertTrue(result.help)
    XCTAssertFalse(result.json)
    XCTAssertNil(result.target)
    XCTAssertEqual(result.positionals, [])
  }

  func testMissingCommonTargetValueNamesTheFlag() {
    let parser = CommandArgumentParser(
      targetFlags: ["-t", "--target"],
      allowsPositionals: false,
      repeatedTarget: .lastWins,
      commandName: "focus"
    )

    XCTAssertThrowsError(try parser.parse(["-t"])) { error in
      XCTAssertEqual(String(describing: error), "focus requires a value after -t")
    }

    XCTAssertThrowsError(try parser.parse(["--target"])) { error in
      XCTAssertEqual(String(describing: error), "focus requires a value after --target")
    }
  }

  func testMissingCommandSpecificValueFlagNamesTheFlag() {
    let parser = CommandArgumentParser(
      targetFlags: ["-t"],
      allowsPositionals: false,
      repeatedTarget: .lastWins,
      valueFlags: ["--cwd": "cwd", "--title": "title"],
      commandName: "new"
    )

    XCTAssertThrowsError(try parser.parse(["--cwd"])) { error in
      XCTAssertEqual(String(describing: error), "new requires a value after --cwd")
    }

    XCTAssertThrowsError(try parser.parse(["--title"])) { error in
      XCTAssertEqual(String(describing: error), "new requires a value after --title")
    }
  }

  func testUnexpectedFlagsAreRejectedButPositionalsCanBeCollected() {
    let parser = CommandArgumentParser(
      targetFlags: ["-t"],
      allowsPositionals: true,
      repeatedTarget: .lastWins
    )

    XCTAssertThrowsError(try parser.parse(["send-key", "--bad-flag", "Tab"])) { error in
      XCTAssertEqual(String(describing: error), "unexpected argument: --bad-flag")
    }
  }

  func testRepeatedTargetPolicySupportsLastWinsAndRejectDuplicates() throws {
    let lastWinsParser = CommandArgumentParser(
      targetFlags: ["-t", "--target"],
      allowsPositionals: false,
      repeatedTarget: .lastWins
    )

    let lastWins = try lastWinsParser.parse(["-t", "surface-1", "--target", "surface-2"])

    XCTAssertEqual(lastWins.target, "surface-2")

    let rejectRepeatsParser = CommandArgumentParser(
      targetFlags: ["-t", "--target"],
      allowsPositionals: false,
      repeatedTarget: .reject(message: "screenshot accepts only one target")
    )

    XCTAssertThrowsError(
      try rejectRepeatsParser.parse(["-t", "surface-1", "-t", "surface-2"])
    ) { error in
      XCTAssertEqual(String(describing: error), "screenshot accepts only one target")
    }
  }
}
