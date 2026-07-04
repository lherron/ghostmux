# ghostmux Agent Enablement Retro

Hand-maintained carrier for agent-enablement retrospectives and reusable
lessons. `AGENT_ENABLEMENT_STATUS.md` is the generated assessment/status
projection; this file records post-assessment routing decisions and evidence
that should survive between generated sweeps.

## Routing Categories

Use one or more of these categories for each entry:

- Docs: durable prose in `README.md`, `AGENTS.md`, or `docs/`.
- Checks: executable gates in `Justfile`, `Tests/`, or repo-local hooks.
- Runbooks: operational procedures in `runbooks/`.
- Skills/process: agent workflow rules, closeout routes, or task handoff
  patterns that are not target code.
- Tacit/manual residue: lessons that are intentionally left as human judgment
  until repeated failures justify mechanizing them.

## Current Posture

As of the 2026-07-03 remediation lane, the target-local remediation set from
the accepted AE baseline assessment has landed in this repo. The generated
`AGENT_ENABLEMENT_STATUS.md` still reflects the source assessment snapshot
from T-05526 until the agent-enablement source regenerates it; use the entries
below for the current post-remediation evidence in this target.

Evidence verified in the tree:

- `af7f993` added the `just verify` closeout gate in `Justfile`.
- `69c5bfc` added repo-local hook materialization through `.githooks/pre-commit`,
  `.githooks/pre-push`, and `just install-hooks`.
- `a497f6c` added command-surface conformance in
  `Tests/command_surface_conformance.sh`.
- `ec731dd` made runtime smoke skip semantics explicit in
  `Tests/ghostmux_smoke.sh`.
- `bc5b5dc` added this repo's agent router at `AGENTS.md`.
- `9c0ffab` added suppression-cost review and guard coverage through
  `docs/SUPPRESSION_GUARD.md`, `Tests/suppression_guard.sh`, and
  `Tests/suppression_guard_baseline.tsv`.

## Entries

### 2026-07-03 - T-05526 / T-05238 AE Remediation Closeout

Source: accepted AE baseline assessment T-05526, lineage T-05238.

Routing:

- Docs: `AGENTS.md` is now the repo-neutral router and points agents at the
  build, verify, install, smoke, suppression, and retro carriers.
- Checks: `just verify` now composes build, Swift formatting lint,
  command-surface conformance, suppression-cost guard, and non-skippable runtime
  smoke.
- Checks: repo-local pre-commit and pre-push hooks run `just verify` after
  `just install-hooks` or `just install` materializes them.
- Checks: `Tests/command_surface_conformance.sh` compares the live CLI registry,
  source command declarations, root help, per-command help, README examples, and
  AGENTS command references.
- Checks: `Tests/suppression_guard.sh` requires reviewed suppression/bypass
  entries to stay inside `Tests/suppression_guard_baseline.tsv`.
- Runbooks: existing smoke procedures remain in `runbooks/smoke-test-runbook.md`
  and `runbooks/ghostchat-identity-smoke-test.md`; no new runbook is needed for
  this retrospective carrier.
- Skills/process: closeout now routes through `AGENTS.md`: verify, install, then
  real installed-binary smoke against local ScriptableGhostty configuration for
  code/runtime changes.
- Tacit/manual residue: broad Swift style taste, terminal-control judgment, and
  whether a skipped smoke is acceptable outside closeout remain manual calls.
  The mechanized guard only permits explicit skip evidence for deliberate
  non-closeout `just test` runs.

Disposition:

- The assessment-time `delta:add-enable-retro-carrier` is addressed by this
  file and its `AGENTS.md` router link.
- Future lessons should be appended here first, then promoted to docs, checks,
  runbooks, or skills/process when they recur often enough to justify stronger
  machinery.
