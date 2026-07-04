# Suppression Guard

ghostmux treats guard bypasses as visible, bounded cost. `just verify` runs
`just check-suppressions`, which scans the concrete local guard surface:

- `GHOSTMUX_SMOKE_ALLOW_SKIP` references;
- Swift formatter directives such as `swift-format-ignore`, `swift-format-ignore-file`,
  and `swift-format-disable`;
- Git hook bypass affordances such as `--no-verify`, `HUSKY=0`, `LEFTHOOK=0`,
  `SKIP=1`, and `core.hooksPath=/dev/null`.

The reviewed inventory is `Tests/suppression_guard_baseline.tsv`. Every accepted
entry must include this greppable marker in the reason column:

```text
SUPPRESSION-REVIEWED[T-xxxxx]: rationale for accepting the suppression cost
```

Valid reviewed baseline entry:

```text
swift-format-directive	1	Sources/example.swift	// swift-format-ignore: parser fixture intentionally preserves spacing	SUPPRESSION-REVIEWED[T-05533]: parser fixture needs byte-stable spacing.
```

Invalid unreviewed source addition:

```bash
GHOSTMUX_SMOKE_ALLOW_SKIP=1 just verify
```

When a reviewed change intentionally adds suppression cost, update the baseline
inventory in the same change. The guard fails on both new unreviewed entries and
stale baseline entries so the budget remains exact.
