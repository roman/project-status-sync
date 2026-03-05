#!/usr/bin/env bash
# Run RALPH sessions in a loop with automatic restart.
# Requires: nix develop --impure (claude-headless must be in PATH)
# Usage: ./scripts/ralph-loop.sh [prompt] [timeout-per-session]
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SESSION_TIMEOUT="${2:-120}"
RATE_LIMIT_WAIT=60

if ! command -v claude-headless &>/dev/null; then
    echo "ERROR: claude-headless not in PATH. Run: nix develop --impure" >&2
    exit 1
fi

kill_zombies() {
    local found=0

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

    local stale_pids
    stale_pids=$(pgrep -f 'bwrap.*claude' 2>/dev/null || true)
    for pid in $stale_pids; do
        echo "Killing orphaned bwrap process (PID: $pid)"
        kill "$pid" 2>/dev/null || true
        found=1
    done

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

DEFAULT_PROMPT='Read RALPH.md for your operating instructions.
Read WORKPLAN.md to understand project state.

Pick ONE small, concrete task from the next pending phase — preferably the next unchecked chunk.
Follow the workflow described in RALPH.md, then exit. Your job is exactly one commit per session.'

PROMPT="${1:-$DEFAULT_PROMPT}"

mkdir -p "$PROJECT_DIR/tmp"

run_session() {
    local iteration=$1
    local logfile="$PROJECT_DIR/tmp/ralph-loop-${iteration}.log"

    kill_zombies

    echo "$PROMPT" > "$PROJECT_DIR/.ralph-prompt"

    local session_dir="$HOME/.claude/projects/-home-roman-project"
    mkdir -p "$session_dir"
    local before
    before=$(ls "$session_dir"/*.jsonl 2>/dev/null | sort || true)
    local commits_before
    commits_before=$(git -C "$PROJECT_DIR" rev-list --count HEAD 2>/dev/null || echo 0)

    cd "$PROJECT_DIR"
    env -u CLAUDECODE claude-headless . > "$logfile" 2>&1 &
    local sandbox_pid=$!

    local cleanup_done=0
    cleanup() {
        if [ "$cleanup_done" -eq 0 ] && kill -0 "$sandbox_pid" 2>/dev/null; then
            kill "$sandbox_pid" 2>/dev/null || true
        fi
        cleanup_done=1
    }
    trap cleanup EXIT

    for i in $(seq 1 "$SESSION_TIMEOUT"); do
        sleep 1

        if ! kill -0 "$sandbox_pid" 2>/dev/null; then
            wait "$sandbox_pid" 2>/dev/null
            local exit_code=$?

            local commits_after
            commits_after=$(git -C "$PROJECT_DIR" rev-list --count HEAD 2>/dev/null || echo 0)
            local new_commits=$((commits_after - commits_before))

            echo "  Exited (code: $exit_code) after ${i}s — $new_commits new commit(s)"
            if [ "$new_commits" -gt 0 ]; then
                git -C "$PROJECT_DIR" log --oneline -"$new_commits" | sed 's/^/    /'
            fi

            trap - EXIT
            return "$exit_code"
        fi

        if (( i % 10 == 0 )); then
            local after
            after=$(ls "$session_dir"/*.jsonl 2>/dev/null | sort || true)
            local new_session
            new_session=$(comm -13 <(echo "$before") <(echo "$after") | tail -1)

            if [ -n "$new_session" ]; then
                local lines
                lines=$(wc -l < "$new_session")
                echo "  [${i}s] lines=$lines"
            else
                echo "  [${i}s] waiting for session..."
            fi
        fi
    done

    echo "  TIMEOUT after ${SESSION_TIMEOUT}s — killing"
    kill "$sandbox_pid" 2>/dev/null || true
    wait "$sandbox_pid" 2>/dev/null || true
    trap - EXIT
    return 1
}

# Main loop
ITERATION=0
echo "=== RALPH Loop Started ==="
echo "Session timeout: ${SESSION_TIMEOUT}s"
echo "Rate limit wait: ${RATE_LIMIT_WAIT}s"
echo ""

while true; do
    ITERATION=$((ITERATION + 1))

    # Check stop signal before starting
    if [ -f "$PROJECT_DIR/.ralph-stop" ]; then
        echo "[iter $ITERATION] Stop file found — exiting loop"
        rm -f "$PROJECT_DIR/.ralph-stop"
        break
    fi

    echo "[iter $ITERATION] Starting session (log: $PROJECT_DIR/tmp/ralph-loop-${ITERATION}.log)"

    set +e
    run_session "$ITERATION"
    EXIT_CODE=$?
    set -e

    # Check stop signal after session
    if [ -f "$PROJECT_DIR/.ralph-stop" ]; then
        echo "[iter $ITERATION] Stop file found — exiting loop"
        rm -f "$PROJECT_DIR/.ralph-stop"
        break
    fi

    case "$EXIT_CODE" in
        0|1)
            echo "[iter $ITERATION] Restarting..."
            echo ""
            ;;
        2)
            echo "[iter $ITERATION] Rate limited — waiting ${RATE_LIMIT_WAIT}s..."
            sleep "$RATE_LIMIT_WAIT"
            echo ""
            ;;
        *)
            echo "[iter $ITERATION] Error (exit $EXIT_CODE) — stopping loop"
            echo "Check $PROJECT_DIR/tmp/ralph-loop-${ITERATION}.log for details"
            break
            ;;
    esac
done

echo "=== RALPH Loop Finished (${ITERATION} iterations) ==="
