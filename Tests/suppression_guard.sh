#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BASELINE="$ROOT/Tests/suppression_guard_baseline.tsv"
REVIEWED_FORMAT='SUPPRESSION-REVIEWED[T-xxxxx]: rationale'

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

failures=0

fail() {
  echo "suppression-guard: ERROR: $*" >&2
  failures=1
}

include_file() {
  local rel="$1"

  if [[ "$rel" == "Tests/suppression_guard.sh" ]]; then
    return 1
  fi

  case "$rel" in
    Sources/*.swift|Sources/*/*.swift|Sources/*/*/*.swift|Tests/*.sh|.githooks/*|Justfile|README.md|AGENTS.md|CLAUDE.md)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

scan_file() {
  local rel="$1"
  local path="$ROOT/$rel"

  awk -v file="$rel" '
    function trim(value) {
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
      gsub(/[[:space:]]+/, " ", value)
      return value
    }

    {
      text = trim($0)
      if ($0 ~ /GHOSTMUX_SMOKE_ALLOW_SKIP/) {
        print "smoke-allow-skip\t" file "\t" FNR "\t" text
      }
      if ($0 ~ /swift-format-(ignore-file|ignore|disable)([^[:alnum:]_-]|$)/) {
        print "swift-format-directive\t" file "\t" FNR "\t" text
      }
      if ($0 ~ /(^|[[:space:]])--no-verify([^[:alnum:]_-]|$)|(^|[[:space:]])HUSKY=0([^[:alnum:]_-]|$)|(^|[[:space:]])LEFTHOOK=0([^[:alnum:]_-]|$)|(^|[[:space:]])SKIP=(1|true|TRUE)([^[:alnum:]_-]|$)|core\.hooksPath[[:space:]]*=[[:space:]]*\/dev\/null/) {
        print "hook-bypass\t" file "\t" FNR "\t" text
      }
    }
  ' "$path"
}

if [[ ! -f "$BASELINE" ]]; then
  fail "baseline file not found: $BASELINE"
fi

while IFS= read -r -d '' path; do
  rel="${path#"$ROOT"/}"
  if include_file "$rel"; then
    scan_file "$rel"
  fi
done < <(find "$ROOT" -type f -print0) >"$tmpdir/raw.tsv"

sort -t $'\t' -k1,1 -k2,2 -k3,3n "$tmpdir/raw.tsv" \
  | awk -F '\t' 'BEGIN { OFS = FS } { base = $1 FS $2 FS $4; counts[base] += 1; print $1, counts[base], $2, $3, $4 }' \
  >"$tmpdir/live.tsv"

awk -F '\t' '
  BEGIN { OFS = FS }
  /^[[:space:]]*#/ || NF == 0 { next }
  NF != 5 {
    print "invalid-baseline\t" FNR "\t" $0 > "/dev/stderr"
    next
  }
  {
    print $1, $2, $3, $4, $5
  }
' "$BASELINE" >"$tmpdir/baseline.tsv" 2>"$tmpdir/baseline.parse.err"

if [[ -s "$tmpdir/baseline.parse.err" ]]; then
  while IFS= read -r line; do
    fail "$line"
  done <"$tmpdir/baseline.parse.err"
fi

awk -F '\t' -v format="$REVIEWED_FORMAT" '
  $5 !~ /SUPPRESSION-REVIEWED\[T-[0-9][0-9][0-9][0-9][0-9]\]: / || length($5) < 55 {
    printf "%s:%s %s lacks reviewed exception marker matching %s\n", $3, $2, $1, format
  }
' "$tmpdir/baseline.tsv" >"$tmpdir/bad-reasons.txt"

if [[ -s "$tmpdir/bad-reasons.txt" ]]; then
  while IFS= read -r line; do
    fail "$line"
  done <"$tmpdir/bad-reasons.txt"
fi

awk -F '\t' 'BEGIN { OFS = FS } { print $1, $2, $3, $5 }' "$tmpdir/live.tsv" | sort >"$tmpdir/live.keys"
awk -F '\t' 'BEGIN { OFS = FS } { print $1, $2, $3, $4 }' "$tmpdir/baseline.tsv" | sort >"$tmpdir/baseline.keys"

comm -23 "$tmpdir/live.keys" "$tmpdir/baseline.keys" >"$tmpdir/unreviewed.keys"
comm -13 "$tmpdir/live.keys" "$tmpdir/baseline.keys" >"$tmpdir/stale.keys"

if [[ -s "$tmpdir/unreviewed.keys" ]]; then
  fail "found unreviewed suppression/bypass entries"
  while IFS=$'\t' read -r kind ordinal path text; do
    line="$(awk -F '\t' -v kind="$kind" -v ordinal="$ordinal" -v path="$path" -v text="$text" '$1 == kind && $2 == ordinal && $3 == path && $5 == text { print $4; exit }' "$tmpdir/live.tsv")"
    echo "suppression-guard: unreviewed: $path:$line [$kind#$ordinal] $text" >&2
  done <"$tmpdir/unreviewed.keys"
fi

if [[ -s "$tmpdir/stale.keys" ]]; then
  fail "baseline contains stale suppression/bypass entries"
  while IFS=$'\t' read -r kind ordinal path text; do
    echo "suppression-guard: stale: $path [$kind#$ordinal] $text" >&2
  done <"$tmpdir/stale.keys"
fi

awk -F '\t' '{ counts[$1] += 1 } END { for (kind in counts) print kind "\t" counts[kind] }' "$tmpdir/live.tsv" \
  | sort >"$tmpdir/live.counts"
awk -F '\t' '{ counts[$1] += 1 } END { for (kind in counts) print kind "\t" counts[kind] }' "$tmpdir/baseline.tsv" \
  | sort >"$tmpdir/baseline.counts"

if ! diff -u "$tmpdir/baseline.counts" "$tmpdir/live.counts" >"$tmpdir/counts.diff"; then
  fail "live suppression counts differ from reviewed baseline budget"
  sed 's/^/suppression-guard: budget: /' "$tmpdir/counts.diff" >&2
fi

if [[ "$failures" -ne 0 ]]; then
  echo "suppression-guard: use SUPPRESSION-REVIEWED[T-xxxxx]: rationale in Tests/suppression_guard_baseline.tsv for reviewed exceptions." >&2
  exit 1
fi

counts="$(awk -F '\t' '{ counts[$1] += 1 } END { for (kind in counts) printf "%s=%d ", kind, counts[kind] }' "$tmpdir/live.tsv" | sed 's/[[:space:]]$//')"
echo "suppression-guard OK: ${counts:-no suppressions}"
