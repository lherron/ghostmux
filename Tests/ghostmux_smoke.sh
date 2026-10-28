#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="${GHOSTMUX_BIN:-$ROOT/.build/debug/ghostmux}"
ALLOW_SKIP="${GHOSTMUX_SMOKE_ALLOW_SKIP:-0}"

json_escape() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  value="${value//$'\n'/\\n}"
  printf '%s' "$value"
}

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
    echo "GHOSTMUX_SMOKE_RESULT=skipped"
    echo "GHOSTMUX_SMOKE_SKIP_REASON=ghostty_socket_missing"
    printf 'GHOSTMUX_SMOKE_SKIP_EVIDENCE={"result":"skipped","reason":"ghostty_socket_missing","socket":"%s","allow_skip":"%s"}\n' \
      "$(json_escape "$SOCK")" "$(json_escape "$ALLOW_SKIP")"
    echo "SKIP: Ghostty socket not found at $SOCK (GHOSTMUX_SMOKE_ALLOW_SKIP=$ALLOW_SKIP)"
    exit 0
  fi

  echo "GHOSTMUX_SMOKE_RESULT=failed"
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

cleanup_result="not_run"
cleanup_done=0

cleanup() {
  if [[ "$cleanup_done" == "1" ]]; then
    return 0
  fi

  cleanup_done=1
  if "$BIN" kill-surface -t "$target" --force >/dev/null 2>&1; then
    cleanup_result="killed"
  else
    cleanup_result="failed"
  fi
}
trap cleanup EXIT

if [[ "$created" == *'"focused":'* ]]; then
  echo "FAIL: ghostmux new must not report asynchronous focus status"
  exit 1
fi

sleep 1
"$BIN" send-keys -t "$target" C-g >/dev/null
"$BIN" capture-pane -t "$target" >/dev/null

# The smoke terminal opens in the background so it never takes Lance's keyboard
# focus. When another window covers it, the server refuses the screenshot with
# 409 terminal_not_visible (scriptable-ghostty T-10764); that refusal is the
# correct answer on an occluded desktop, so it passes as "occluded".
shot="$(mktemp -t ghostmux-screenshot-smoke).png"
if shot_err="$("$BIN" screenshot -t "$target" -o "$shot" 2>&1 >/dev/null)"; then
  file "$shot" | grep -q "PNG image data"
  screenshot_validation="png"
elif [[ "$shot_err" == *"not on screen"* ]]; then
  echo "screenshot: terminal occluded (409 terminal_not_visible), counted as pass"
  screenshot_validation="occluded"
else
  echo "FAIL: screenshot: $shot_err"
  exit 1
fi
rm -f "$shot"

cleanup
trap - EXIT

echo "GHOSTMUX_SMOKE_RESULT=passed"
printf 'GHOSTMUX_SMOKE_EVIDENCE={"result":"passed","binary_path":"%s","socket_path":"%s","created_short_id":"%s","exercised_commands":["new","send-keys","capture-pane","screenshot","kill-surface"],"screenshot_validation":"%s","cleanup_result":"%s"}\n' \
  "$(json_escape "$BIN")" \
  "$(json_escape "$SOCK")" \
  "$(json_escape "$target")" \
  "$screenshot_validation" \
  "$(json_escape "$cleanup_result")"
echo "OK"
