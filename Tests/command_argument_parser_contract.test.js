import { describe, expect, test } from "bun:test";
import {
  cpSync,
  existsSync,
  mkdirSync,
  mkdtempSync,
  rmSync,
  writeFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { spawnSync } from "node:child_process";

const root = new URL("..", import.meta.url).pathname;

function parserTargetPath() {
  return join(root, "Sources/GhostmuxCommandParsing");
}

function makeSwiftTestPackage() {
  const dir = mkdtempSync(join(tmpdir(), "ghostmux-command-parser-"));
  mkdirSync(join(dir, "Sources"), { recursive: true });
  cpSync(parserTargetPath(), join(dir, "Sources/GhostmuxCommandParsing"), { recursive: true });

  writeFileSync(
    join(dir, "Package.swift"),
    `// swift-tools-version:5.9
import PackageDescription

let package = Package(
  name: "ghostmux-command-parser-contract",
  platforms: [.macOS(.v13)],
  products: [],
  targets: [
    .target(name: "GhostmuxCommandParsing", path: "Sources/GhostmuxCommandParsing"),
    .testTarget(
      name: "GhostmuxCommandParsingTests",
      dependencies: ["GhostmuxCommandParsing"],
      path: "Tests/GhostmuxCommandParsingTests"
    ),
  ]
)
`,
  );

  mkdirSync(join(dir, "Tests/GhostmuxCommandParsingTests"), { recursive: true });
  writeFileSync(
    join(dir, "Tests/GhostmuxCommandParsingTests/CommandArgumentParserTests.swift"),
    `import XCTest
@testable import GhostmuxCommandParsing

final class CommandArgumentParserTests: XCTestCase {
  private func parse(
    _ args: [String],
    targetPolicy: CommandArgumentParseOptions.RepeatedTargetPolicy = .lastWins,
    positionals: CommandArgumentParseOptions.PositionalPolicy = .collect,
    valueFlags: [String] = []
  ) throws -> CommandArgumentParseResult {
    try CommandArgumentParser.parse(
      args,
      options: CommandArgumentParseOptions(
        supportsJSON: true,
        targetAliases: ["-t", "--target"],
        repeatedTarget: targetPolicy,
        positionals: positionals,
        valueFlags: Set(valueFlags)
      )
    )
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
        "expected error containing \\(expected), got \\(message)",
        file: file,
        line: line
      )
    }
  }

  func testHelpJSONTargetAliasesAndOrderedPositionals() throws {
    // T-05631: the shared parser owns common flag scanning while preserving
    // command-owned positional payload order for send-key, metadata, and similar commands.
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
    assertMessage(try parse(["--cwd"], valueFlags: ["--cwd"]), contains: "requires a value after --cwd")
    assertMessage(try parse(["--title"], valueFlags: ["--title"]), contains: "requires a value after --title")
    assertMessage(try parse(["--command"], valueFlags: ["--command"]), contains: "requires a value after --command")
    assertMessage(try parse(["--env"], valueFlags: ["--env"]), contains: "requires a value after --env")
    assertMessage(try parse(["-d"], valueFlags: ["-d"]), contains: "requires a value after -d")
    assertMessage(try parse(["-S"], valueFlags: ["-S"]), contains: "requires a value after -S")
    assertMessage(try parse(["-E"], valueFlags: ["-E"]), contains: "requires a value after -E")
    assertMessage(try parse(["-o"], valueFlags: ["-o"]), contains: "requires a value after -o")
    assertMessage(try parse(["--fg"], valueFlags: ["--fg"]), contains: "requires a value after --fg")
    assertMessage(try parse(["--bg"], valueFlags: ["--bg"]), contains: "requires a value after --bg")
  }

  func testUnexpectedFlagsAndRejectedPositionalsAreExplicit() throws {
    assertMessage(try parse(["--bogus"]), contains: "unexpected argument: --bogus")
    assertMessage(
      try parse(["payload"], positionals: .reject),
      contains: "unexpected argument: payload"
    )
  }

  func testRepeatedTargetPoliciesPreserveExistingCommandBoundaries() throws {
    let lastWins = try parse(["-t", "first-pane", "--target", "second-pane"])
    XCTAssertEqual(lastWins.target, "second-pane")

    assertMessage(
      try parse(["-t", "first-pane", "--target", "second-pane"], targetPolicy: .reject),
      contains: "target specified multiple times"
    )
  }
}
`,
  );

  return dir;
}

describe("ghostmux command argument parser contract", () => {
  test("parser source is isolated in a testable SwiftPM target", () => {
    expect(
      existsSync(parserTargetPath()),
      "T-05631 requires a small shared parser target at Sources/GhostmuxCommandParsing",
    ).toBe(true);
  });

  test("parser behavior covers common flags, scoped target policies, and positional preservation", () => {
    if (!existsSync(parserTargetPath())) {
      expect(
        false,
        "T-05631 parser behavior cannot run until Sources/GhostmuxCommandParsing exists",
      ).toBe(true);
      return;
    }

    const dir = makeSwiftTestPackage();
    try {
      const result = spawnSync(
        "swift",
        ["test", "--filter", "^GhostmuxCommandParsingTests.CommandArgumentParserTests"],
        {
          cwd: dir,
          encoding: "utf8",
          timeout: 120_000,
        },
      );

      expect(
        result.status,
        `swift parser behavior contract should pass once the shared parser exists.\nSTDOUT:\n${result.stdout}\nSTDERR:\n${result.stderr}`,
      ).toBe(0);
    } finally {
      rmSync(dir, { recursive: true, force: true });
    }
  }, 150_000);
});
