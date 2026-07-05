import { expect, test } from "bun:test";

test("GhostmuxCommandParsing Swift parser unit tests pass", async () => {
  const proc = Bun.spawn({
    cmd: ["swift", "test", "--filter", "CommandArgumentParserTests"],
    stdout: "pipe",
    stderr: "pipe",
  });

  const [stdout, stderr, exitCode] = await Promise.all([
    new Response(proc.stdout).text(),
    new Response(proc.stderr).text(),
    proc.exited,
  ]);

  // Red-bar context: this outer Bun assertion must collect cleanly while the
  // inner Swift XCTest spec defines the parser behavior the implementation owes.
  expect(
    { exitCode, stdout, stderr },
    [stdout, stderr].filter(Boolean).join("\n")
  ).toMatchObject({ exitCode: 0 });
});
