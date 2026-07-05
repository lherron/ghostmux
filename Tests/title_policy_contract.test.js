import { describe, expect, test } from "bun:test";
import { existsSync, readdirSync, readFileSync, statSync } from "node:fs";
import { join } from "node:path";

const root = new URL("..", import.meta.url).pathname;

function readRepoFile(path) {
  return readFileSync(join(root, path), "utf8");
}

function swiftFilesUnder(path) {
  const dir = join(root, path);
  if (!existsSync(dir)) {
    return [];
  }

  const files = [];
  for (const entry of readdirSync(dir)) {
    const fullPath = join(dir, entry);
    const stat = statSync(fullPath);
    if (stat.isDirectory()) {
      files.push(...swiftFilesUnder(join(path, entry)));
    } else if (entry.endsWith(".swift")) {
      files.push(join(path, entry));
    }
  }
  return files;
}

function readTitlePolicySource() {
  return swiftFilesUnder("Sources/GhosttyLib")
    .filter((path) => /Title|TerminalTitle/.test(path))
    .map((path) => readRepoFile(path))
    .find(
      (source) =>
        source.includes("TerminalTitle") &&
        source.includes("setTitle") &&
        source.includes("sendText"),
    );
}

describe("terminal title policy contract", () => {
  test("GhosttyLib exposes one shared policy for title validation, delay, endpoint use, fallback, and results", () => {
    // T-05635 red bar: commands must delegate title mechanics to one testable policy.
    const policy = readTitlePolicySource();

    expect(policy, "expected a GhosttyLib TerminalTitle policy source file").toBeDefined();
    expect(policy).toContain("TerminalTitleResult");
    expect(policy).toContain("invalid");
    expect(policy).toContain("fallback");
    expect(policy).toContain("setTitle");
    expect(policy).toContain("sendText");
    expect(policy).toMatch(/delay|sleep|postCreate/i);
  });

  test("new and set-title delegate mechanics instead of carrying duplicate validation or fallback branches", () => {
    const newCommand = readRepoFile("Sources/ghostmux/Commands/NewCommand.swift");
    const setTitleCommand = readRepoFile("Sources/ghostmux/Commands/SetTitleCommand.swift");

    expect(newCommand).toContain("TerminalTitle");
    expect(setTitleCommand).toContain("TerminalTitle");

    for (const [path, source] of [
      ["Sources/ghostmux/Commands/NewCommand.swift", newCommand],
      ["Sources/ghostmux/Commands/SetTitleCommand.swift", setTitleCommand],
    ]) {
      expect(source, `${path} should not validate ESC locally`).not.toContain('contains("\\u{1b}")');
      expect(source, `${path} should not validate BEL locally`).not.toContain('contains("\\u{07}")');
      expect(source, `${path} should not branch on endpoint-unavailable locally`).not.toContain(
        "Endpoint not found",
      );
    }

    expect(setTitleCommand).not.toContain("oscPrintfCommand");
    expect(setTitleCommand).not.toMatch(/apiError\(let status/);
    expect(newCommand).not.toContain("usleep(1_000_000)");
  });

  test("set-title JSON output explicitly reports direct and fallback success paths", () => {
    const setTitleCommand = readRepoFile("Sources/ghostmux/Commands/SetTitleCommand.swift");

    expect(setTitleCommand).toContain('"success"');
    expect(setTitleCommand).toMatch(/fallback|title_/i);
    expect(setTitleCommand).not.toMatch(/sendText[\s\S]*return/);
  });
});
