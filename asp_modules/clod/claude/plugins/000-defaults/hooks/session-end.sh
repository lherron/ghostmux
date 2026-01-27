#!/bin/bash
# Session end hook (multi-harness)

MARKER_DIR="${TMPDIR:-/tmp}/asp-session-start"
MARKER_FILE="$MARKER_DIR/$(pwd | tr -c '[:alnum:]' '_' )"

if [ -f "$MARKER_FILE" ]; then
  rm -f "$MARKER_FILE" 2>/dev/null || true
fi

exit 0
