#!/usr/bin/env bash
# Run a single RALPH session in the bubblewrap sandbox with monitoring.
# Requires: nix develop --impure (claude-headless must be in PATH)
# Usage: ./scripts/ralph-test.sh [prompt] [timeout]
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TIMEOUT="${2:-120}"

if ! command -v claude-headless &>/dev/null; then
    echo "ERROR: claude-headless not in PATH. Run: nix develop --impure" >&2
    exit 1
fi

# Kill zombie processes from previous runs
kill_zombies() {
    local found=0

    # Stale squid proxies (tracked by pid files)
    for pidfile in /tmp/claude-sandbox-proxy/squid.*.pid; do
        [ -f "$pidfile" ] || continue
        local pid
        pid=$(cat "$pidfile" 2>/dev/null) || continue
        if kill -0 "$pid" 2>/dev/null; then
            echo "Killing stale squid proxy (PID: $pid)"
            kill "$pid" 2>/dev/null || true
            sleep 0.5
            kill -9 "$pid" 2>/dev/null || true
            found=1
        fi
        rm -f "$pidfile"
    done

    # Orphaned bwrap processes running claude
    local stale_pids
    stale_pids=$(pgrep -f 'bwrap.*claude' 2>/dev/null || true)
    for pid in $stale_pids; do
        echo "Killing orphaned bwrap process (PID: $pid)"
        kill "$pid" 2>/dev/null || true
        found=1
    done

    # Orphaned claude processes inside dead sandboxes (parent is init)
    stale_pids=$(pgrep -f 'claude.*-p.*--dangerously' 2>/dev/null || true)
    for pid in $stale_pids; do
        local ppid
        ppid=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')
        if [ "$ppid" = "1" ]; then
            echo "Killing orphaned claude process (PID: $pid, reparented to init)"
            kill "$pid" 2>/dev/null || true
            found=1
        fi
    done

    if [ "$found" -eq 1 ]; then
        sleep 1
        echo "Zombie cleanup done."
    fi
}

kill_zombies

DEFAULT_PROMPT='Read WORKPLAN.md to understand project state.

Pick ONE small, concrete task from the next pending phase — preferably Phase 1.1 (signal format definition) or any other clearly scoped chunk.

Do the following in order:
1. Implement the task (keep it minimal)
2. Update WORKPLAN.md progress checkboxes
3. Append to progress.log
4. Commit all changes together

After committing, create the file `.ralph-stop` and then exit immediately. Do NOT start another task. Your job is exactly one commit, then stop.'

PROMPT="${1:-$DEFAULT_PROMPT}"

# Write prompt
echo "$PROMPT" > "$PROJECT_DIR/.ralph-prompt"
echo "Prompt written to .ralph-prompt (${#PROMPT} chars)"

# Determine session dir — bwrap mounts project at ~/project, so claude
# creates sessions under -home-roman-project, not the real path
SESSION_DIR="$HOME/.claude/projects/-home-roman-project"
mkdir -p "$SESSION_DIR"

# Snapshot existing sessions
BEFORE=$(ls "$SESSION_DIR"/*.jsonl 2>/dev/null | sort || true)

# Record git state before
COMMITS_BEFORE=$(git -C "$PROJECT_DIR" rev-list --count HEAD 2>/dev/null || echo 0)

# Launch sandbox
echo "Starting sandbox (timeout: ${TIMEOUT}s)..."
echo "Project: $PROJECT_DIR"
echo "---"

cd "$PROJECT_DIR"
env -u CLAUDECODE claude-headless . > /tmp/ralph-test.log 2>&1 &
SANDBOX_PID=$!

cleanup() {
    if kill -0 "$SANDBOX_PID" 2>/dev/null; then
        echo "Cleaning up sandbox (PID $SANDBOX_PID)..."
        kill "$SANDBOX_PID" 2>/dev/null || true
    fi
}
trap cleanup EXIT

for i in $(seq 1 "$TIMEOUT"); do
    sleep 1

    if ! kill -0 "$SANDBOX_PID" 2>/dev/null; then
        wait "$SANDBOX_PID" 2>/dev/null
        EXIT=$?

        COMMITS_AFTER=$(git -C "$PROJECT_DIR" rev-list --count HEAD 2>/dev/null || echo 0)
        NEW_COMMITS=$((COMMITS_AFTER - COMMITS_BEFORE))

        echo "[${i}s] Exited (code: $EXIT)"
        echo "=== Summary ==="
        echo "New commits: $NEW_COMMITS"
        if [ "$NEW_COMMITS" -gt 0 ]; then
            echo "--- Last commit ---"
            git -C "$PROJECT_DIR" log --oneline -"$NEW_COMMITS"
        fi
        if [ -f "$PROJECT_DIR/.ralph-stop" ]; then
            echo "Stop file: created (RALPH would not loop)"
            rm -f "$PROJECT_DIR/.ralph-stop"
        fi
        echo "=== Sandbox output (last 20 lines) ==="
        tail -20 /tmp/ralph-test.log
        exit $EXIT
    fi

    if (( i % 5 == 0 )); then
        AFTER=$(ls "$SESSION_DIR"/*.jsonl 2>/dev/null | sort || true)
        NEW_SESSION=$(comm -13 <(echo "$BEFORE") <(echo "$AFTER") | tail -1)

        if [ -n "$NEW_SESSION" ]; then
            LINES=$(wc -l < "$NEW_SESSION")
            LAST_TYPE=$(tail -1 "$NEW_SESSION" | jq -r '.type // .message.role // "?"' 2>/dev/null)
            echo "[${i}s] session=$(basename "$NEW_SESSION" .jsonl | head -c 8).. lines=$LINES last=$LAST_TYPE"
        else
            echo "[${i}s] waiting for session file..."
        fi
    fi
done

echo "[${TIMEOUT}s] TIMEOUT — killing sandbox"
kill "$SANDBOX_PID" 2>/dev/null || true
echo "=== Sandbox output (last 20 lines) ==="
tail -20 /tmp/ralph-test.log
exit 1
