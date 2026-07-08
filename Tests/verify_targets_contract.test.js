import { describe, expect, test } from "bun:test";
import { readFileSync } from "node:fs";
import { join } from "node:path";

const root = new URL("..", import.meta.url).pathname;

function readRepoFile(path) {
  return readFileSync(join(root, path), "utf8");
}

function recipeHeaderPattern(name) {
  return new RegExp(`^${name}(?::|\\s)`, "m");
}

function recipeBlock(source, name) {
  const match = source.match(new RegExp(`^${name}[^\\n]*\\n(?:[ \\t].*\\n|\\n)*`, "m"));
  return match?.[0] ?? "";
}

function recipeLine(source, name) {
  return source.match(new RegExp(`^${name}[^\\n]*`, "m"))?.[0] ?? "";
}

describe("verify target legibility contract", () => {
  test("just verify composes named per-concern predicates that delegate to the existing checks", () => {
    // T-05802 red bar: keep the same quality gate, but split its checks into
    // named predicates so failures point at the build, lint, docs, suppression,
    // or smoke concern directly.
    const justfile = readRepoFile("Justfile");
    const expectedPredicates = [
      "verify-tests",
      "verify-command-surface",
      "verify-suppressions",
      "verify-smoke",
    ];

    for (const name of expectedPredicates) {
      expect(justfile, `Justfile should define ${name}`).toMatch(recipeHeaderPattern(name));
    }

    const verifyHeader = recipeLine(justfile, "verify");
    for (const name of expectedPredicates) {
      expect(verifyHeader, `just verify should compose ${name}`).toContain(name);
    }

    const verifyTests = `${recipeLine(justfile, "verify-tests")}\n${recipeBlock(justfile, "verify-tests")}`;
    expect(verifyTests).toContain("build");
    expect(verifyTests).toContain("lint");

    const verifyCommandSurface =
      `${recipeLine(justfile, "verify-command-surface")}\n${recipeBlock(justfile, "verify-command-surface")}`;
    expect(verifyCommandSurface).toMatch(/command-surface|Tests\/command_surface_conformance\.sh/);

    const verifySuppressions =
      `${recipeLine(justfile, "verify-suppressions")}\n${recipeBlock(justfile, "verify-suppressions")}`;
    expect(verifySuppressions).toMatch(/check-suppressions|Tests\/suppression_guard\.sh/);

    expect(recipeBlock(justfile, "verify-smoke")).toContain("GHOSTMUX_SMOKE_ALLOW_SKIP=0");
    expect(recipeBlock(justfile, "verify-smoke")).toContain("Tests/ghostmux_smoke.sh");
  });
});
