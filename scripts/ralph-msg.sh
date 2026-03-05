#!/usr/bin/env bash
# Send a message to a running RALPH agent and wait for a reply.
# Usage: ./scripts/ralph-msg.sh "What phase are you working on?"
#        ./scripts/ralph-msg.sh                # opens $EDITOR
#        RALPH_MSG_TIMEOUT=60 ./scripts/ralph-msg.sh "quick question"
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
MSGS_DIR="$PROJECT_DIR/.msgs"
TIMEOUT="${RALPH_MSG_TIMEOUT:-300}"
POLL_INTERVAL=2

mkdir -p "$MSGS_DIR"

# Get message content
if [ $# -gt 0 ]; then
    MESSAGE="$1"
else
    TMPFILE=$(mktemp $PROJECT_DIR/tmp/ralph-msg-XXXXXX.md)
    trap 'rm -f "$TMPFILE"' EXIT
    ${EDITOR:-vi} "$TMPFILE"
    MESSAGE=$(cat "$TMPFILE")
    if [ -z "$MESSAGE" ]; then
        echo "Empty message, aborting." >&2
        exit 1
    fi
fi

# Generate request ID
REQID=$(head -c4 /dev/urandom | xxd -p)

# Write message
echo "$MESSAGE" > "$MSGS_DIR/$REQID.md"
echo "Sent message [$REQID] — waiting for reply (timeout: ${TIMEOUT}s)..."

# Poll for reply
ELAPSED=0
while [ "$ELAPSED" -lt "$TIMEOUT" ]; do
    if [ -f "$MSGS_DIR/$REQID.reply.md" ]; then
        echo "---"
        cat "$MSGS_DIR/$REQID.reply.md"
        echo "---"
        rm -f "$MSGS_DIR/$REQID.md" "$MSGS_DIR/$REQID.reply.md"
        exit 0
    fi
    sleep "$POLL_INTERVAL"
    ELAPSED=$((ELAPSED + POLL_INTERVAL))
    if (( ELAPSED % 30 == 0 )); then
        echo "[${ELAPSED}s] still waiting..."
    fi
done

echo "Timeout after ${TIMEOUT}s — no reply received." >&2
echo "Message left at: .msgs/$REQID.md" >&2
exit 1
