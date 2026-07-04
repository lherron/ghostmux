#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="${GHOSTMUX_BIN:-$ROOT/.build/debug/ghostmux}"
ALLOW_SKIP="${GHOSTMUX_SMOKE_ALLOW_SKIP:-0}"

if [[ ! -x "$BIN" ]]; then
  echo "ghostmux binary not found at $BIN"
  exit 1
fi

SOCK="${GHOSTTY_API_SOCKET:-$HOME/Library/Application Support/Ghostty/api.sock}"
if [[ ! -S "$SOCK" ]]; then
  "$BIN" status >/dev/null 2>&1 || true
fi

if [[ ! -S "$SOCK" ]]; then
  if [[ "$ALLOW_SKIP" == "1" || "$ALLOW_SKIP" == "true" ]]; then
    echo "SKIP: Ghostty socket not found at $SOCK (GHOSTMUX_SMOKE_ALLOW_SKIP=$ALLOW_SKIP)"
    exit 0
  fi

  echo "FAIL: Ghostty socket not found at $SOCK"
  echo "FAIL: start ScriptableGhostty or set GHOSTTY_API_SOCKET; set GHOSTMUX_SMOKE_ALLOW_SKIP=1 only when an explicit skip is acceptable outside just verify"
  exit 1
fi

created="$("$BIN" new --title ghostmux-smoke --command "echo ghostmux_smoke && sleep 20" --json)"
target="$(printf '%s\n' "$created" | sed -n 's/.*"short_id":"\([^"]*\)".*/\1/p')"

if [[ -z "$target" ]]; then
  echo "FAIL: could not parse created target"
  exit 1
fi

cleanup() {
  "$BIN" kill-surface -t "$target" --force >/dev/null 2>&1 || true
}
trap cleanup EXIT

sleep 1
"$BIN" send-keys -t "$target" C-g >/dev/null
"$BIN" capture-pane -t "$target" >/dev/null

shot="$(mktemp -t ghostmux-screenshot-smoke).png"
"$BIN" screenshot -t "$target" -o "$shot" >/dev/null
file "$shot" | grep -q "PNG image data"
rm -f "$shot"

echo "OK"
