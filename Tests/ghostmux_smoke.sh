#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="${GHOSTMUX_BIN:-$ROOT/.build/debug/ghostmux}"

if [[ ! -x "$BIN" ]]; then
  echo "ghostmux binary not found at $BIN"
  exit 1
fi

SOCK="${GHOSTTY_API_SOCKET:-$HOME/Library/Application Support/Ghostty/api.sock}"
if [[ ! -S "$SOCK" ]]; then
  "$BIN" status >/dev/null 2>&1 || true
fi

if [[ ! -S "$SOCK" ]]; then
  echo "SKIP: Ghostty socket not found at $SOCK"
  exit 0
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
