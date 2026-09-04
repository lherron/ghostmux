import XCTest

@testable import GhostmuxCommandParsing

final class CommandArgumentParserTests: XCTestCase {
  private func parse(
    _ args: [String],
    targetPolicy: CommandArgumentParseOptions.RepeatedTargetPolicy = .lastWins,
    positionals: CommandArgumentParseOptions.PositionalPolicy = .collect,
    booleanFlags: Set<String> = [],
    valueFlags: Set<String> = [],
    flagLikePositionals: Bool = false
  ) throws -> CommandArgumentParseResult {
    try CommandArgumentParser.parse(
      args,
      options: CommandArgumentParseOptions(
        supportsJSON: true,
        targetAliases: ["-t", "--target"],
        repeatedTarget: targetPolicy,
        positionals: positionals,
        booleanFlags: booleanFlags,
        valueFlags: valueFlags,
        flagLikePositionals: flagLikePositionals
      )
    )
  }

  func testCommonFlagsTargetAliasesAndPositionals() throws {
    let parsed = try parse([
      "--json",
      "--target", "first-pane",
      "metadata",
      "-t", "second-pane",
      "set",
      "title",
      "--help",
    ])

    XCTAssertTrue(parsed.help)
    XCTAssertTrue(parsed.json)
    XCTAssertEqual(parsed.target, "second-pane")
    XCTAssertEqual(parsed.positionals, ["metadata", "set", "title"])
  }

  func testMissingCommonAndCommandSpecificFlagValuesStaySpecific() throws {
    assertMessage(try parse(["-t"]), contains: "requires a value after -t")
    assertMessage(try parse(["--target"]), contains: "requires a value after --target")
    assertMessage(
      try parse(["--cwd"], valueFlags: ["--cwd"]), contains: "requires a value after --cwd")
    assertMessage(
      try parse(["--title"], valueFlags: ["--title"]),
      contains: "requires a value after --title")
    assertMessage(
      try parse(["--command"], valueFlags: ["--command"]),
      contains: "requires a value after --command")
    assertMessage(
      try parse(["--env"], valueFlags: ["--env"]), contains: "requires a value after --env")
    assertMessage(try parse(["-d"], valueFlags: ["-d"]), contains: "requires a value after -d")
    assertMessage(try parse(["-S"], valueFlags: ["-S"]), contains: "requires a value after -S")
    assertMessage(try parse(["-E"], valueFlags: ["-E"]), contains: "requires a value after -E")
    assertMessage(try parse(["-o"], valueFlags: ["-o"]), contains: "requires a value after -o")
    assertMessage(
      try parse(["--fg"], valueFlags: ["--fg"]), contains: "requires a value after --fg")
    assertMessage(
      try parse(["--bg"], valueFlags: ["--bg"]), contains: "requires a value after --bg")
  }

  func testUnexpectedFlagsAndRejectedPositionalsAreExplicit() throws {
    assertMessage(try parse(["--bogus"]), contains: "unexpected argument: --bogus")
    assertMessage(
      try parse(["payload"], positionals: .reject),
      contains: "unexpected argument: payload")
  }

  func testRepeatedTargetPolicies() throws {
    let lastWins = try parse(["-t", "first-pane", "--target", "second-pane"])
    XCTAssertEqual(lastWins.target, "second-pane")

    assertMessage(
      try parse(["-t", "first-pane", "--target", "second-pane"], targetPolicy: .reject),
      contains: "target specified multiple times")
  }

  func testCommandSpecificFlagsKeepOrderAndValues() throws {
    let parsed = try parse(
      ["--window", "--env", "A=1", "--tab", "--env", "B=2", "--cwd", "/tmp"],
      positionals: .reject,
      booleanFlags: ["--window", "--tab"],
      valueFlags: ["--env", "--cwd"]
    )

    XCTAssertEqual(parsed.flagOrder, ["--window", "--tab"])
    XCTAssertEqual(parsed.values(for: "--env"), ["A=1", "B=2"])
    XCTAssertEqual(parsed.value(for: "--cwd"), "/tmp")
  }

  func testStatusBarBarFlagKeepsItsValueAlongsideSubcommandPositionals() throws {
    // `statusbar` parses with flagLikePositionals, so `--bar` must be declared as a
    // value flag or "secondary" would be swallowed as a positional.
    let parsed = try parse(
      ["set", "--bar", "secondary", "L2|C2|R2"],
      booleanFlags: ["--window"],
      valueFlags: ["--fg", "--bg", "--bar"],
      flagLikePositionals: true
    )

    XCTAssertEqual(parsed.value(for: "--bar"), "secondary")
    XCTAssertEqual(parsed.positionals, ["set", "L2|C2|R2"])

    assertMessage(
      try parse(["--bar"], valueFlags: ["--bar"]), contains: "requires a value after --bar")
  }

  func testFlagLikePositionalsAreOptIn() throws {
    assertMessage(try parse(["-dash-title"]), contains: "unexpected argument: -dash-title")

    let parsed = try parse(["-dash-title"], flagLikePositionals: true)
    XCTAssertEqual(parsed.positionals, ["-dash-title"])
  }

  private func assertMessage(
    _ expression: @autoclosure () throws -> CommandArgumentParseResult,
    contains expected: String,
    file: StaticString = #filePath,
    line: UInt = #line
  ) {
    XCTAssertThrowsError(try expression(), file: file, line: line) { error in
      let message = String(describing: error)
      XCTAssertTrue(
        message.contains(expected),
        "expected error containing \(expected), got \(message)",
        file: file,
        line: line
      )
    }
  }
}
