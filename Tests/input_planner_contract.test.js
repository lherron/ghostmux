import { describe, expect, test } from "bun:test";
import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";

const root = new URL("..", import.meta.url).pathname;

function readRepoFile(path) {
  return readFileSync(join(root, path), "utf8");
}

function countMatches(source, pattern) {
  return Array.from(source.matchAll(pattern)).length;
}

describe("input planner consolidation contract", () => {
  test("GhosttyLib owns one input planner and one named/control key parser", () => {
    // T-05634: the commands must delegate token planning to GhosttyLib instead of
    // keeping separate named-key tables and C-/Ctrl- parsing branches.
    const plannerPath = "Sources/GhosttyLib/InputPlanner.swift";
    expect(
      existsSync(join(root, plannerPath)),
      `${plannerPath} should define the shared send-key/send-keys planning layer`,
    ).toBe(true);

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
    expect(
      existsSync(join(root, plannerPath)),
      `${plannerPath} should define behavior policy instead of embedding it in commands`,
    ).toBe(true);

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
});
