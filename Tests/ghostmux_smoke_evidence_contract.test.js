import { afterEach, describe, expect, test } from "bun:test";
import { spawnSync } from "node:child_process";
import {
  chmodSync,
  mkdtempSync,
  readFileSync,
  rmSync,
  writeFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { createServer } from "node:net";

const root = new URL("..", import.meta.url).pathname;
const tempDirs = [];

afterEach(() => {
  for (const dir of tempDirs.splice(0)) {
    rmSync(dir, { recursive: true, force: true });
  }
});

function makeTempDir() {
  const dir = mkdtempSync(join(tmpdir(), "ghostmux-smoke-evidence-"));
  tempDirs.push(dir);
  return dir;
}

function writeFakeGhostmux(dir) {
  const bin = join(dir, "ghostmux");
  const pngBase64 =
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/p9sAAAAASUVORK5CYII=";

  writeFileSync(
    bin,
    `#!/usr/bin/env bash
set -euo pipefail
printf '%s\\n' "$1" >>"${dir}/commands.log"
case "$1" in
  status)
    exit 0
    ;;
  new)
    printf '{"short_id":"smoke-proof"}\\n'
    ;;
  send-keys|capture-pane|kill-surface)
    exit 0
    ;;
  screenshot)
    out=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        -o)
          out="$2"
          shift 2
          ;;
        *)
          shift
          ;;
      esac
    done
    printf '${pngBase64}' | base64 --decode >"$out"
    ;;
  *)
    echo "unexpected ghostmux command: $1" >&2
    exit 64
    ;;
esac
`,
  );
  chmodSync(bin, 0o755);
  return bin;
}

function listenOnUnixSocket(path) {
  const server = createServer((socket) => socket.end());
  return new Promise((resolve, reject) => {
    server.once("error", reject);
    server.listen(path, () => {
      server.off("error", reject);
      resolve(server);
    });
  });
}

describe("ghostmux smoke evidence contract", () => {
  test("successful smoke emits one machine-readable evidence JSON line with proof fields", async () => {
    // T-05810 red bar: the runtime smoke may still print its existing human lines,
    // but a successful pass must also expose structured proof for automation.
    const dir = makeTempDir();
    const fakeBin = writeFakeGhostmux(dir);
    const socketPath = join(dir, "api.sock");
    const server = await listenOnUnixSocket(socketPath);

    try {
      const result = spawnSync("bash", ["Tests/ghostmux_smoke.sh"], {
        cwd: root,
        env: {
          ...process.env,
          GHOSTMUX_BIN: fakeBin,
          GHOSTTY_API_SOCKET: socketPath,
          GHOSTMUX_SMOKE_ALLOW_SKIP: "0",
        },
        encoding: "utf8",
        timeout: 30_000,
      });

      expect(
        result.status,
        `smoke script should reach its pass path with the bounded fake binary.\nSTDOUT:\n${result.stdout}\nSTDERR:\n${result.stderr}`,
      ).toBe(0);
      expect(result.stdout).toContain("GHOSTMUX_SMOKE_RESULT=passed");

      const evidenceLine = result.stdout
        .split(/\r?\n/)
        .find((line) => line.startsWith("GHOSTMUX_SMOKE_EVIDENCE="));
      expect(
        evidenceLine,
        `pass output should include GHOSTMUX_SMOKE_EVIDENCE JSON.\nSTDOUT:\n${result.stdout}`,
      ).toBeDefined();

      const evidence = JSON.parse(evidenceLine.replace("GHOSTMUX_SMOKE_EVIDENCE=", ""));
      expect(evidence).toMatchObject({
        result: "passed",
        binary_path: fakeBin,
        socket_path: socketPath,
        created_short_id: "smoke-proof",
        screenshot_validation: "png",
        cleanup_result: "killed",
      });
      expect(evidence.exercised_commands).toEqual([
        "new",
        "send-keys",
        "capture-pane",
        "screenshot",
        "kill-surface",
      ]);

      const commandLog = readFileSync(join(dir, "commands.log"), "utf8")
        .trim()
        .split(/\r?\n/);
      expect(commandLog).toEqual(evidence.exercised_commands);
    } finally {
      await new Promise((resolve) => server.close(resolve));
    }
  });
});
