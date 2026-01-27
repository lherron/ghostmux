#!/usr/bin/env python3
"""
Hook to log failed Bash command executions.

- Claude: PostToolUseFailure (legacy) or PostToolUse payload
- Pi: ASP_* env vars from hook bridge

Logs to ~/.claude/bash-failures.log
"""
import json
import sys
from datetime import datetime
import os
import re

LOG_FILE = os.path.expanduser("~/.claude/bash-failures.log")


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


def extract_exit_code(error_message: str | None):
    if not error_message:
        return None
    match = re.match(r"Exit code (\d+)", error_message)
    if match:
        return int(match.group(1))
    return None


def main():
    hook_input = load_hook_input()

    # Only process Bash tool failures
    if hook_input.get("tool_name") != "Bash":
        sys.exit(0)

    tool_input = hook_input.get("tool_input") or hook_input.get("tool_args") or {}
    tool_result = hook_input.get("tool_output") or hook_input.get("tool_result") or {}

    # Attempt to extract error details
    error_message = (
        hook_input.get("error")
        or (tool_result.get("error") if isinstance(tool_result, dict) else None)
        or (tool_result.get("stderr") if isinstance(tool_result, dict) else None)
    )

    exit_code = None
    if isinstance(tool_result, dict):
        exit_code = tool_result.get("exit_code") or tool_result.get("exitCode")
    if exit_code is None:
        exit_code = extract_exit_code(error_message)

    # If we still don't see failure signals, exit quietly
    if (exit_code is None or exit_code == 0) and not error_message:
        sys.exit(0)

    timestamp = datetime.now().isoformat()

    log_entry = {
        "timestamp": timestamp,
        "exit_code": exit_code,
        "command": tool_input.get("command") if isinstance(tool_input, dict) else None,
        "description": tool_input.get("description") if isinstance(tool_input, dict) else None,
        "error_message": error_message,
        "is_interrupt": hook_input.get("is_interrupt", False),
        "session_id": hook_input.get("session_id"),
        "cwd": hook_input.get("cwd"),
        "tool_use_id": hook_input.get("tool_use_id"),
    }

    try:
        with open(LOG_FILE, "a") as f:
            f.write(json.dumps(log_entry, indent=2) + "\n---\n")
        cmd = None
        if isinstance(tool_input, dict):
            cmd = tool_input.get("command")
        cmd = (cmd or "N/A")[:40]
        print(f"[LOGGED FAILURE] exit={exit_code} cmd={cmd}...")
    except Exception as e:
        print(f"Error writing to log: {e}", file=sys.stderr)
        sys.exit(1)

    sys.exit(0)


if __name__ == "__main__":
    main()
