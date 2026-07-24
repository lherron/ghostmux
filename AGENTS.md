# AGENTS.md

Agent guide for ghostmux — a Swift CLI controlling
[ScriptableGhostty](https://github.com/lherron/scriptable-ghostty) terminals over
a Unix domain socket. Two executables: `ghostmux` (terminal control) and
`ghostchat` (inter-agent messaging).

- `Justfile` is the authority for build, verify, install, hook, and smoke recipes (`just --list`).
- `README.md` owns user-facing command examples; `Tests/command_surface_conformance.sh` compares README coverage with the live CLI registry and rejects stale command references in this file.
- `docs/SUPPRESSION_GUARD.md` defines the reviewed exception format enforced by `just check-suppressions`.
- `AGENT_ENABLEMENT_STATUS.md` is a generated projection (do not hand-edit); `AGENT_ENABLEMENT_RETRO.md` is the hand-maintained retro carrier.

`just install` builds release binaries, materializes the repo hooks (which run
`just verify` on pre-commit/pre-push), and installs `ghostmux` and `ghostchat`
to `~/.local/bin/`.

## Architecture

- **GhosttyLib** — shared library: `GhosttyClient` (UDS client), `Models`, `KeyStroke` parsing (special keys like C-c, Tab, modifier combos), `Utils` (target resolution, socket path, JSON output).
- **ghostmux** — command-pattern CLI: each command is a struct conforming to `GhostmuxCommand` in `Sources/ghostmux/Commands/`, registered in the `commandTypes` array in `main.swift`.
- **ghostchat** — messaging CLI; deterministic friendly names from UUIDs, protocol `[ghostchat:<sender-name>] <message>`.

UDS protocol: 4-byte big-endian length prefix + JSON envelope (`version`,
`method`, `path`, optional `query`/`body`); responses are length-prefixed JSON
with `status` and `body`. API version `v2`. Socket path:
`~/Library/Application Support/Ghostty/api.sock`, overridable via
`GHOSTTY_API_SOCKET`.

## Runtime Smoke Contract

Real runtime smoke (`Tests/ghostmux_smoke.sh`, run by `just test` and
`just verify`) requires ScriptableGhostty to expose the socket. Interpret the
output literally:

- `GHOSTMUX_SMOKE_RESULT=passed` — real terminal behavior was exercised.
- `GHOSTMUX_SMOKE_RESULT=failed` — a required runtime check failed.
- `GHOSTMUX_SMOKE_RESULT=skipped` is **not a pass**. It must include `GHOSTMUX_SMOKE_SKIP_EVIDENCE=...` and is only acceptable when deliberately running `GHOSTMUX_SMOKE_ALLOW_SKIP=1 just test` outside the closeout gate.

`just verify` forces `GHOSTMUX_SMOKE_ALLOW_SKIP=0`, so a missing Ghostty socket
fails verification instead of producing green skip evidence. A skip is never
acceptable closeout evidence for ghostmux changes.

## Closeout Route

For code or runtime changes: `just verify`, then `just install`, then smoke the
installed binary from `~/.local/bin/` against real local configuration — at
minimum confirm `~/.local/bin/ghostmux status` reaches ScriptableGhostty, and
exercise any changed command path directly. For documentation-only changes,
run the referenced recipes and path checks for every command or file named in
the doc.
