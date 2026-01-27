#!/usr/bin/env python3
"""
Hook to log ALL Bash tool calls (request + response).

- Claude: receives JSON payload on stdin (PostToolUse)
- Pi: receives ASP_* env vars from hook bridge

Logs to ~/.claude/bash-all.log
"""
import json
import sys
from datetime import datetime
import os

LOG_FILE = os.path.expanduser("~/.claude/bash-all.log")


def load_hook_input():
    raw_input = sys.stdin.read()
    if raw_input.strip():
        try:
            return json.loads(raw_input)
        except json.JSONDecodeError as e:
            print(f"Error: Invalid JSON input: {e}", file=sys.stderr)
            sys.exit(1)

    # Pi hook bridge: use env vars
    return {
        "tool_name": os.environ.get("ASP_TOOL_NAME"),
        "tool_args": json.loads(os.environ.get("ASP_TOOL_ARGS", "{}")),
        "tool_result": json.loads(os.environ.get("ASP_TOOL_RESULT", "{}")),
        "source": "pi",
    }


def main():
    hook_input = load_hook_input()

    # Only process Bash tool
    if hook_input.get("tool_name") != "Bash":
        sys.exit(0)

    timestamp = datetime.now().isoformat()

    # Log the ENTIRE raw payload to see all available fields
    log_entry = {
        "timestamp": timestamp,
        "raw_hook_payload": hook_input,  # Full payload for investigation
    }

    try:
        with open(LOG_FILE, "a") as f:
            f.write(json.dumps(log_entry, indent=2) + "\n---\n")
        cmd = None
        tool_input = hook_input.get("tool_input") or hook_input.get("tool_args") or {}
        if isinstance(tool_input, dict):
            cmd = tool_input.get("command")
        cmd = (cmd or "N/A")[:40]
        print(f"[LOGGED ALL] {cmd}...")
    except Exception as e:
        print(f"Error writing to log: {e}", file=sys.stderr)
        sys.exit(1)

    sys.exit(0)


if __name__ == "__main__":
    main()
