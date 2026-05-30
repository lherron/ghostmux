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

surfaces="$("$BIN" list-surfaces)"
if [[ -z "$surfaces" ]] || [[ "$surfaces" == "(no terminals)" ]]; then
  echo "SKIP: no terminals"
  exit 0
fi

target="$(printf '%s\n' "$surfaces" | sed -n 's/^Created pane: .* (\([^)]*\)).*/\1/p' | head -n 1)"
if [[ -z "$target" ]]; then
  echo "SKIP: could not parse target"
  exit 0
fi

"$BIN" send-keys -t "$target" C-g >/dev/null
"$BIN" capture-pane -t "$target" >/dev/null

echo "OK"
