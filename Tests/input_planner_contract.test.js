import { describe, expect, test } from "bun:test";
import {
  cpSync,
  existsSync,
  mkdirSync,
  mkdtempSync,
  readFileSync,
  rmSync,
  writeFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { spawnSync } from "node:child_process";

const root = new URL("..", import.meta.url).pathname;

function readRepoFile(path) {
  return readFileSync(join(root, path), "utf8");
}

function countMatches(source, pattern) {
  return Array.from(source.matchAll(pattern)).length;
}

function expectPlannerSourceExists() {
  const plannerPath = "Sources/GhosttyLib/InputPlanner.swift";
  expect(
    existsSync(join(root, plannerPath)),
    `${plannerPath} should define the shared send-key/send-keys planning layer`,
  ).toBe(true);
}

function makeSwiftTestPackage() {
  const dir = mkdtempSync(join(tmpdir(), "ghostmux-input-planner-"));
  cpSync(join(root, "Sources"), join(dir, "Sources"), { recursive: true });

  writeFileSync(
    join(dir, "Package.swift"),
    `// swift-tools-version:5.9
import PackageDescription

let package = Package(
  name: "ghostmux-input-planner-contract",
  platforms: [.macOS(.v13)],
  products: [],
  targets: [
    .target(name: "GhosttyLib", path: "Sources/GhosttyLib"),
    .testTarget(
      name: "GhosttyLibTests",
      dependencies: ["GhosttyLib"],
      path: "Tests/GhosttyLibTests"
    ),
  ]
)
`,
  );

  mkdirSync(join(dir, "Tests/GhosttyLibTests"), { recursive: true });
  writeFileSync(
    join(dir, "Tests/GhosttyLibTests/InputPlannerBehaviorTests.swift"),
    `import XCTest
@testable import GhosttyLib

final class InputPlannerBehaviorTests: XCTestCase {
  private func sendKeysPolicy(appendEnter: Bool = true) -> InputPlanPolicy {
    InputPlanPolicy(
      literal: false,
      textGrouping: .joined(separator: " "),
      recognizeSpecialTokens: true,
      appendEnter: appendEnter,
      appendEnterDelayMicros: appendEnter ? 200_000 : nil
    )
  }

  private func sendKeyPolicy() -> InputPlanPolicy {
    InputPlanPolicy(
      literal: false,
      textGrouping: .individualTokens,
      recognizeSpecialTokens: true,
      appendEnter: false,
      appendEnterDelayMicros: nil
    )
  }

  private func literalPolicy() -> InputPlanPolicy {
    InputPlanPolicy(
      literal: true,
      textGrouping: .joined(separator: " "),
      recognizeSpecialTokens: false,
      appendEnter: false,
      appendEnterDelayMicros: nil
    )
  }

  private func assertText(_ operation: InputPlanOperation, _ expected: String, file: StaticString = #filePath, line: UInt = #line) {
    guard case .text(let actual) = operation else {
      return XCTFail("expected text operation, got \\(operation)", file: file, line: line)
    }
    XCTAssertEqual(actual, expected, file: file, line: line)
  }

  private func assertKey(
    _ operation: InputPlanOperation,
    key expectedKey: String,
    mods expectedMods: [String] = [],
    file: StaticString = #filePath,
    line: UInt = #line
  ) {
    guard case .key(let stroke) = operation else {
      return XCTFail("expected key operation, got \\(operation)", file: file, line: line)
    }
    XCTAssertEqual(stroke.key, expectedKey, file: file, line: line)
    XCTAssertEqual(stroke.mods, expectedMods, file: file, line: line)
  }

  func testPlainAndMultiTokenTextStayAsTextChunks() throws {
    let plain = try InputPlanner.plan(tokens: ["hello"], policy: sendKeysPolicy(appendEnter: false))
    XCTAssertEqual(plain.count, 1)
    assertText(plain[0], "hello")

    let multiToken = try InputPlanner.plan(tokens: ["echo", "hello"], policy: sendKeysPolicy(appendEnter: false))
    XCTAssertEqual(multiToken.count, 1)
    assertText(multiToken[0], "echo hello")

    let sendKeyTokens = try InputPlanner.plan(tokens: ["left", "right"], policy: sendKeyPolicy())
    XCTAssertEqual(sendKeyTokens.count, 2)
    assertText(sendKeyTokens[0], "left")
    assertText(sendKeyTokens[1], "right")
  }

  func testTokenModeFlushesTextAroundSpecialKeys() throws {
    let plan = try InputPlanner.plan(
      tokens: ["echo", "Tab", "done", "Escape", "C-c"],
      policy: sendKeysPolicy(appendEnter: false)
    )

    XCTAssertEqual(plan.count, 5)
    assertText(plan[0], "echo")
    assertKey(plan[1], key: "tab")
    assertText(plan[2], "done")
    assertKey(plan[3], key: "escape")
    assertKey(plan[4], key: "c", mods: ["ctrl"])
  }

  func testLiteralModeDoesNotInterpretSpecialLookingTokens() throws {
    let plan = try InputPlanner.plan(tokens: ["Tab", "C-c", "Escape"], policy: literalPolicy())

    XCTAssertEqual(plan.count, 1)
    assertText(plan[0], "Tab C-c Escape")
  }

  func testInvalidControlFormsAreErrorsOnlyInTokenMode() throws {
    XCTAssertThrowsError(try InputPlanner.plan(tokens: ["C-"], policy: sendKeysPolicy(appendEnter: false)))
    XCTAssertThrowsError(try InputPlanner.plan(tokens: ["Ctrl-NotAKey"], policy: sendKeysPolicy(appendEnter: false)))

    let literal = try InputPlanner.plan(tokens: ["C-", "Ctrl-NotAKey"], policy: literalPolicy())
    XCTAssertEqual(literal.count, 1)
    assertText(literal[0], "C- Ctrl-NotAKey")
  }

  func testSendKeysAppendsEnterByDefaultAndNoEnterOmitsIt() throws {
    let defaultPlan = try InputPlanner.plan(tokens: ["echo", "ok"], policy: sendKeysPolicy())
    XCTAssertEqual(defaultPlan.count, 2)
    assertText(defaultPlan[0], "echo ok")
    assertKey(defaultPlan[1], key: "enter")

    let noEnterPlan = try InputPlanner.plan(tokens: ["echo", "ok"], policy: sendKeysPolicy(appendEnter: false))
    XCTAssertEqual(noEnterPlan.count, 1)
    assertText(noEnterPlan[0], "echo ok")
  }
}
`,
  );

  return dir;
}

describe("input planner consolidation contract", () => {
  test("GhosttyLib owns one input planner and one named/control key parser", () => {
    // T-05634: the commands must delegate token planning to GhosttyLib instead of
    // keeping separate named-key tables and C-/Ctrl- parsing branches.
    const plannerPath = "Sources/GhosttyLib/InputPlanner.swift";
    expectPlannerSourceExists();

    const planner = readRepoFile(plannerPath);
    const keyStroke = readRepoFile("Sources/GhosttyLib/KeyStroke.swift");
    const sendKey = readRepoFile("Sources/ghostmux/Commands/SendKeyCommand.swift");
    const sendKeys = readRepoFile("Sources/ghostmux/Commands/SendKeysCommand.swift");
    const commandSources = `${sendKey}\n${sendKeys}`;

    expect(planner).toContain("InputPlanner");
    expect(planner).toContain("InputPlanPolicy");
    expect(planner).toContain("InputPlanOperation");
    expect(planner).toMatch(/case\s+text\s*\(\s*String\s*\)/);
    expect(planner).toMatch(/case\s+key\s*\(\s*KeyStroke\s*\)/);
    expect(planner).toMatch(/plan\s*\(\s*tokens:\s*\[String\]\s*,\s*policy:\s*InputPlanPolicy\s*\)\s*throws/);

    expect(keyStroke).toMatch(/keyStrokeForNamedOrControlToken\s*\(/);
    expect(keyStroke).toMatch(/throws\s*->\s*KeyStroke\?/);

    expect(commandSources).not.toContain("specialKeyStroke(for:");
    expect(commandSources).not.toContain("let namedKeys:");
    expect(commandSources).not.toContain("let ctrlPrefixes");

    const allSources = [
      keyStroke,
      planner,
      sendKey,
      sendKeys,
    ].join("\n");
    expect(
      countMatches(allSources, /\bnamedKeys\s*:\s*\[String\s*:\s*KeyStroke\]/g),
      "named key tables should live in only one canonical KeyStroke-owned parser",
    ).toBeLessThanOrEqual(1);

    for (const [name, source] of [
      ["SendKeyCommand", sendKey],
      ["SendKeysCommand", sendKeys],
    ]) {
      expect(source, `${name} should call the shared input planner`).toContain("InputPlanner");
      expect(source, `${name} should execute planned text chunks`).toContain(".text");
      expect(source, `${name} should execute planned key events`).toContain(".key");
    }
  });

  test("planner policy explicitly preserves text chunking, special tokens, literal mode, and Enter defaults", () => {
    const plannerPath = "Sources/GhosttyLib/InputPlanner.swift";
    expectPlannerSourceExists();

    const planner = readRepoFile(plannerPath);
    const sendKey = readRepoFile("Sources/ghostmux/Commands/SendKeyCommand.swift");
    const sendKeys = readRepoFile("Sources/ghostmux/Commands/SendKeysCommand.swift");

    for (const requiredPolicyTerm of [
      "literal",
      "textGrouping",
      "recognizeSpecialTokens",
      "appendEnter",
      "appendEnterDelayMicros",
    ]) {
      expect(
        planner,
        `InputPlanPolicy should expose ${requiredPolicyTerm} as an explicit command policy choice`,
      ).toContain(requiredPolicyTerm);
    }

    for (const requiredBehaviorToken of [
      "joined",
      "separator",
      "Tab",
      "Escape",
      "C-c",
      "invalid key",
    ]) {
      expect(
        planner,
        `InputPlanner should pin ${requiredBehaviorToken} planning behavior in source`,
      ).toContain(requiredBehaviorToken);
    }

    expect(sendKey).toMatch(/appendEnter\s*:\s*false|appendEnter\s*=\s*false/);
    expect(sendKeys).toMatch(/appendEnter\s*:\s*!noEnter|appendEnter\s*=\s*!noEnter/);
    expect(sendKeys).toMatch(/appendEnterDelayMicros\s*:\s*200_?000|appendEnterDelayMicros\s*=\s*200_?000/);
    expect(sendKeys).not.toContain("usleep(200000)");
  });

  test("shared planner produces the accepted operation sequences", () => {
    expectPlannerSourceExists();

    const dir = makeSwiftTestPackage();
    try {
      const result = spawnSync(
        "swift",
        ["test", "--filter", "^GhosttyLibTests.InputPlannerBehaviorTests"],
        {
          cwd: dir,
          encoding: "utf8",
          timeout: 120_000,
        },
      );

      expect(
        result.status,
        `swift planner behavior contract should pass once the shared planner exists.\nSTDOUT:\n${result.stdout}\nSTDERR:\n${result.stderr}`,
      ).toBe(0);
    } finally {
      rmSync(dir, { recursive: true, force: true });
    }
  }, 150_000);
});
