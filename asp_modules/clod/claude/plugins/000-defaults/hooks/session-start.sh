#!/bin/bash
# Session start hook (multi-harness)
# For Claude, this runs on first tool use via pre_tool_use + guard

MARKER_DIR="${TMPDIR:-/tmp}/asp-session-start"
mkdir -p "$MARKER_DIR"
MARKER_FILE="$MARKER_DIR/$(pwd | tr -c '[:alnum:]' '_' )"

if [ -f "$MARKER_FILE" ]; then
  exit 0
fi

# Mark as started
: > "$MARKER_FILE"

# Check for Justfile/justfile and run just --list if found
if [ -f "Justfile" ] || [ -f "justfile" ]; then
    echo "=== This project uses Justfile ==="
    just --list 2>/dev/null || echo "(just --list failed)"
    echo ""
fi

# Run wrkq info
echo "=== This project uses wrkq ==="
wrkq agent-info 2>/dev/null || echo "(wrkq info failed or not available)"

exit 0
