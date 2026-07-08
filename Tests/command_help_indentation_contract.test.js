import { describe, expect, test } from "bun:test";
import {
  cpSync,
  mkdirSync,
  mkdtempSync,
  rmSync,
  writeFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { spawnSync } from "node:child_process";

const root = new URL("..", import.meta.url).pathname;

function makeCommandHelpTestPackage() {
  const dir = mkdtempSync(join(tmpdir(), "ghostmux-command-help-"));
  mkdirSync(join(dir, "Sources/ghostmux"), { recursive: true });
  mkdirSync(join(dir, "Sources/GhosttyLib"), { recursive: true });
  mkdirSync(join(dir, "Sources/GhostmuxCommandParsing"), { recursive: true });
  mkdirSync(join(dir, "Tests/CommandHelpTests"), { recursive: true });

  cpSync(join(root, "Sources/ghostmux/Command.swift"), join(dir, "Sources/ghostmux/Command.swift"));

  writeFileSync(
    join(dir, "Package.swift"),
    `// swift-tools-version:5.9
import PackageDescription

let package = Package(
  name: "ghostmux-command-help-contract",
  platforms: [.macOS(.v13)],
  targets: [
    .target(name: "GhosttyLib", path: "Sources/GhosttyLib"),
    .target(name: "GhostmuxCommandParsing", path: "Sources/GhostmuxCommandParsing"),
    .target(
      name: "ghostmux",
      dependencies: ["GhosttyLib", "GhostmuxCommandParsing"],
      path: "Sources/ghostmux"
    ),
    .testTarget(name: "CommandHelpTests", dependencies: ["ghostmux"], path: "Tests/CommandHelpTests"),
  ]
)
`,
  );

  writeFileSync(
    join(dir, "Sources/GhosttyLib/Stubs.swift"),
    `public struct Terminal {
  public let id: String
  public let focused: Bool
  public let workingDirectory: String?
  public let columns: Int?
  public let rows: Int?
}

public struct GhosttyClient {}

public enum GhosttyError: Error {
  case message(String)
}

public enum SurfaceResolutionPolicy {
  case focusedTarget
}

public enum SurfaceSelector {
  case argument(String)
  case none
}

public enum SurfaceResolutionError: Error {
  case unresolved

  public static func format(_ error: SurfaceResolutionError) -> String { "surface resolution failed" }
}

public struct SurfaceResolver {
  public init(terminals: [Terminal]) {}
  public func resolve(_ selector: SurfaceSelector, policy: SurfaceResolutionPolicy) throws -> Terminal {
    throw SurfaceResolutionError.unresolved
  }
}

public enum NameGenerator {
  public static func nameFromUUID(_ id: String) -> String { id }
}
`,
  );

  writeFileSync(
    join(dir, "Sources/GhostmuxCommandParsing/Stubs.swift"),
    `public struct CommandArgumentParseResult {
  public let help: Bool
  public let json: Bool
  public let target: String?
  public let positionals: [String]
}

public struct CommandArgumentParseOptions {
  public enum RepeatedTargetPolicy {
    case lastWins
    case reject
  }

  public enum PositionalPolicy {
    case collect
    case reject
  }

  public init(
    supportsJSON: Bool,
    targetAliases: Set<String>,
    repeatedTarget: RepeatedTargetPolicy,
    positionals: PositionalPolicy,
    booleanFlags: Set<String>,
    valueFlags: Set<String>,
    flagLikePositionals: Bool
  ) {}
}

public enum CommandArgumentParser {
  public static func parse(
    _ args: [String],
    options: CommandArgumentParseOptions
  ) throws -> CommandArgumentParseResult {
    CommandArgumentParseResult(help: false, json: false, target: nil, positionals: [])
  }
}
`,
  );

  writeFileSync(
    join(dir, "Tests/CommandHelpTests/CommandHelpTests.swift"),
    `import XCTest
@testable import ghostmux

final class CommandHelpTests: XCTestCase {
  func testCommandHelpPreservesIndentedOptionsRows() {
    // T-05631 defect guard: Swift multiline strings already dedent the help
    // literal, so the shared helper must not strip the option-row indentation
    // required by the command-surface conformance parser.
    let rendered = commandHelp(
      """
      Usage:
        ghostmux new-pane [options]

      Options:
        -t <target>           Target terminal to split (UUID, title, or prefix)
        --json                Output JSON
      """)

    XCTAssertTrue(
      rendered.contains("\\n  -t <target>           Target terminal to split"),
      "commandHelp must preserve the two leading spaces before option rows; got:\\n\\(rendered)"
    )
  }
}
`,
  );

  return dir;
}

describe("ghostmux command help indentation contract", () => {
  test("commandHelp preserves indented Options rows for command-surface parsing", () => {
    const dir = makeCommandHelpTestPackage();
    try {
      const result = spawnSync(
        "swift",
        ["test", "--filter", "^CommandHelpTests.CommandHelpTests/testCommandHelpPreservesIndentedOptionsRows$"],
        {
          cwd: dir,
          encoding: "utf8",
          timeout: 120_000,
        },
      );

      expect(
        result.status,
        `commandHelp should preserve option indentation.\nSTDOUT:\n${result.stdout}\nSTDERR:\n${result.stderr}`,
      ).toBe(0);
    } finally {
      rmSync(dir, { recursive: true, force: true });
    }
  }, 150_000);
});
