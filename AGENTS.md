# AGENTS.md

Agent-facing router for ghostmux. Use this file to land in the right local
context, then defer to the referenced source files for command details.

## Context Map

- `CLAUDE.md` is the compatible architecture and command guide for this repo.
  Keep it aligned with this router when closeout expectations change.
- `Justfile` is the authority for local build, verify, install, hook, and smoke
  recipes.
- `README.md` owns user-facing command examples. `Tests/command_surface_conformance.sh`
  compares README command coverage with the live `ghostmux` CLI registry and
  rejects stale `ghostmux <command>` references in this router.
- `Tests/ghostmux_smoke.sh` is the runtime smoke used by `just test` and
  `just verify`.
- Current agent-enablement baseline: `af7f993..ec731dd` added `just verify`,
  repo-local hooks, command-surface conformance, and explicit smoke skip
  evidence.

## Command Surface

- Build/typecheck: `just build`
- Swift formatting lint: `just lint`
- Command-surface guard: `just command-surface`
- Full closeout gate: `just verify`
- Materialize repo hooks: `just install-hooks`
- Install real binaries: `just install`
- Runtime smoke only: `just test`

`just install` builds release binaries, runs `just install-hooks`, and installs
`ghostmux` and `ghostchat` to `~/.local/bin/`.

## Runtime Smoke Contract

ghostmux controls ScriptableGhostty through a Unix domain socket. Real runtime
smoke requires ScriptableGhostty to expose the socket at
`~/Library/Application Support/Ghostty/api.sock`, or a custom path named by
`GHOSTTY_API_SOCKET`.

Interpret smoke output literally:

- `GHOSTMUX_SMOKE_RESULT=passed` means real terminal behavior was exercised.
- `GHOSTMUX_SMOKE_RESULT=failed` means the required runtime check failed.
- `GHOSTMUX_SMOKE_RESULT=skipped` is not a pass. It must include
  `GHOSTMUX_SMOKE_SKIP_EVIDENCE=...` and is only acceptable when deliberately
  running `GHOSTMUX_SMOKE_ALLOW_SKIP=1 just test` outside the closeout gate.

`just verify` forces `GHOSTMUX_SMOKE_ALLOW_SKIP=0`, so a missing Ghostty socket
fails verification instead of producing green skip evidence.

## Closeout Route

For code or runtime changes, run `just verify`, then `just install`, then smoke
the installed binary from `~/.local/bin/` against real local configuration. At a
minimum, confirm `~/.local/bin/ghostmux status` reaches ScriptableGhostty, and
exercise any changed command path directly.

For documentation-only changes, still run the relevant referenced recipes and
path checks for every command or file named in the doc. Do not report a runtime
smoke as passed unless `Tests/ghostmux_smoke.sh` emitted
`GHOSTMUX_SMOKE_RESULT=passed`.
