#!/bin/bash
# Praesidium startup info - key facts for agents
# Always exits 0 - hooks should never fail

main() {
    LOG_FILE=~/praesidium/var/logs/motd-calls.log
    mkdir -p "$(dirname "$LOG_FILE")"

    # Read the full hook payload from stdin
    PAYLOAD=$(cat)

    # Log with timestamp
    {
        echo "=== $(date -Iseconds) ==="
        echo "$PAYLOAD"
        echo ""
    } >> "$LOG_FILE"

    cat ~/praesidium/AGENT_MOTD.md

    # If cwd contains a justfile, try running 'just info'
    if [[ -f "justfile" || -f "Justfile" ]]; then
        echo ""
        echo "**This project uses a Justfile for running things**"
        just info 2>/dev/null || true
    fi
}

if ! main "$@"; then
    HOOK_LOG=~/praesidium/var/log/hooks-log.log
    mkdir -p "$(dirname "$HOOK_LOG")"
    echo "$(date -Iseconds) [FAIL] agent_motd.sh: main returned non-zero" >> "$HOOK_LOG"
fi
exit 0
