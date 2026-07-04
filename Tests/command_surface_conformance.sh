#!/usr/bin/env bash
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="${GHOSTMUX_BIN:-$ROOT/.build/debug/ghostmux}"
README="${GHOSTMUX_README:-$ROOT/README.md}"
AGENTS="${GHOSTMUX_AGENTS:-$ROOT/AGENTS.md}"
COMMAND_DIR="$ROOT/Sources/ghostmux/Commands"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

failures=0

fail() {
  echo "command-surface: ERROR: $*" >&2
  failures=1
}

compare_files() {
  local label="$1"
  local expected="$2"
  local actual="$3"

  if ! diff -u "$expected" "$actual" >"$tmpdir/$label.diff"; then
    fail "$label drift"
    sed "s/^/command-surface: $label: /" "$tmpdir/$label.diff" >&2
  fi
}

if [[ ! -x "$BIN" ]]; then
  fail "ghostmux binary not found at $BIN"
  exit 1
fi

if [[ ! -f "$README" ]]; then
  fail "README not found at $README"
  exit 1
fi

if [[ ! -f "$AGENTS" ]]; then
  fail "AGENTS router not found at $AGENTS"
  exit 1
fi

if ! "$BIN" __command-surface >"$tmpdir/live.tsv" 2>"$tmpdir/live.err"; then
  fail "failed to read live command registry from $BIN"
  sed 's/^/command-surface: live-registry stderr: /' "$tmpdir/live.err" >&2
  exit 1
fi

sort "$tmpdir/live.tsv" >"$tmpdir/live.sorted.tsv"

awk -F '\t' '
  {
    print $1
    if ($2 != "") {
      n = split($2, aliases, ",")
      for (i = 1; i <= n; i++) print aliases[i]
    }
  }
' "$tmpdir/live.tsv" | sort -u >"$tmpdir/valid-command-tokens.txt"

perl -0ne '
  my ($name) = /static\s+let\s+name\s*=\s*"([^"]+)"/ or next;
  my @aliases = ();
  if (/static\s+let\s+aliases(?:\s*:\s*\[[^\]]+\])?\s*=\s*\[([^\]]*)\]/s) {
    @aliases = $1 =~ /"([^"]+)"/g;
  }
  print "$name\t", join(",", @aliases), "\n";
' "$COMMAND_DIR"/*.swift | sort >"$tmpdir/source.sorted.tsv"

compare_files source-vs-registry "$tmpdir/source.sorted.tsv" "$tmpdir/live.sorted.tsv"

if ! "$BIN" --help >"$tmpdir/root.help" 2>"$tmpdir/root.err"; then
  fail "root help failed"
  sed 's/^/command-surface: root-help stderr: /' "$tmpdir/root.err" >&2
fi

perl -ne '
  $in = 1 if /^\s*Commands:\s*$/;
  $in = 0 if /^\s*Options:\s*$/;
  if ($in && /^\s+([a-z0-9-]+(?:,\s*[a-z0-9-]+)*)\s{2,}/) {
    my @parts = split /,\s*/, $1;
    my $name = shift @parts;
    print "$name\t", join(",", @parts), "\n";
  }
' "$tmpdir/root.help" | sort >"$tmpdir/root.sorted.tsv"

compare_files root-help-vs-registry "$tmpdir/live.sorted.tsv" "$tmpdir/root.sorted.tsv"

while IFS=$'\t' read -r name aliases; do
  help_path="$tmpdir/help.$name.txt"
  err_path="$tmpdir/help.$name.err"
  if ! "$BIN" "$name" --help >"$help_path" 2>"$err_path"; then
    fail "per-command help failed for '$name'"
    sed "s/^/command-surface: $name stderr: /" "$err_path" >&2
    continue
  fi

  if ! grep -q 'Usage:' "$help_path"; then
    fail "per-command help for '$name' does not contain a Usage section"
  fi

  if ! grep -Eq "ghostmux[[:space:]]+$name([^[:alnum:]_-]|$)" "$help_path"; then
    fail "per-command help for '$name' does not reference 'ghostmux $name'"
  fi

  if [[ -n "${aliases:-}" ]]; then
    IFS=',' read -r -a alias_items <<<"$aliases"
    for alias in "${alias_items[@]}"; do
      alias_help_path="$tmpdir/help.alias.$alias.txt"
      alias_err_path="$tmpdir/help.alias.$alias.err"
      if ! "$BIN" "$alias" --help >"$alias_help_path" 2>"$alias_err_path"; then
        fail "alias '$alias' did not resolve to help for '$name'"
        sed "s/^/command-surface: $alias stderr: /" "$alias_err_path" >&2
        continue
      fi

      compare_files "alias-$alias-help-vs-$name" "$help_path" "$alias_help_path"
    done
  fi

  if ! grep -Eq "(^|[^[:alnum:]_-])ghostmux[[:space:]]+$name([^[:alnum:]_-]|$)" "$README"; then
    fail "README does not reference canonical command 'ghostmux $name'"
  fi
done <"$tmpdir/live.tsv"

perl -ne '
  if (/^\s*```/) {
    $in_fence = !$in_fence;
    next;
  }
  while (/`([^`]*)`/g) {
    my $span = $1;
    while ($span =~ /(?:^|[[:space:]\/])ghostmux\s+([a-z0-9-]+)/g) {
      print "$1\n";
    }
  }
  if ($in_fence && /^\s*(?:\$[[:space:]]*)?(?:.*\/)?ghostmux\s+([a-z0-9-]+)/) {
    print "$1\n";
  }
' "$README" "$AGENTS" | sort -u >"$tmpdir/referenced-command-tokens.txt"

if ! comm -23 "$tmpdir/referenced-command-tokens.txt" "$tmpdir/valid-command-tokens.txt" >"$tmpdir/unknown-command-tokens.txt"; then
  fail "failed to compare referenced command tokens"
fi

if [[ -s "$tmpdir/unknown-command-tokens.txt" ]]; then
  fail "docs reference unknown ghostmux command token(s)"
  sed 's/^/command-surface: unknown-token: /' "$tmpdir/unknown-command-tokens.txt" >&2
fi

if [[ "$failures" -ne 0 ]]; then
  exit 1
fi

echo "command-surface conformance OK"
