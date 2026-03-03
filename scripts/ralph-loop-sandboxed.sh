#!/usr/bin/env bash
# ralph-loop-sandboxed.sh — autonomous Claude Code work loop with MicroVM sandboxing
# Runs claude in an ephemeral NixOS VM, isolated from host credentials and other projects.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="${PROJECT_DIR:-$(pwd)}"
FLAKE_DIR="${FLAKE_DIR:-$(dirname "$SCRIPT_DIR")}"
LOGDIR="${LOGDIR:-/tmp/claude-ralph-loop}"
STOPFILE="$PROJECT_DIR/.ralph-stop"
NTFY_TOPIC="${NTFY_TOPIC:-}"

mkdir -p "$LOGDIR"
mkdir -p "$PROJECT_DIR/.msgs"

PROMPT='Read @WORKPLAN.md. Continue from where you left off. Work autonomously through the workplan phases, updating status there as you go. Before context gets low (~15% remaining), update WORKPLAN.md session tracking and handoff notes, commit everything, then exit cleanly. All state must live in committed files (WORKPLAN.md, progress.log, notes/) — do NOT use .claude/ memory files.

Check .msgs/ for any messages from human. Reply by creating a new file there.
'

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOGDIR/loop.log"; }

ntfy() {
    if [[ -n "$NTFY_TOPIC" ]]; then
        curl -s -H "Priority: ${2:-default}" -H "Tags: wrench" -d "$1" "ntfy.sh/$NTFY_TOPIC" >/dev/null 2>&1 || true
    fi
}

check_stop_file() {
    if [[ -f "$STOPFILE" ]]; then
        log "Stop file exists ($STOPFILE). Exiting."
        ntfy "Ralph loop stopped (.ralph-stop exists)" low
        exit 0
    fi
}

run_sandboxed_session() {
    local session_log="$LOGDIR/session-$(date +%Y%m%d-%H%M%S).log"
    log "Starting sandboxed session. Log: $session_log"
    log "Project: $PROJECT_DIR"

    # Write prompt for the VM to read
    echo "$PROMPT" > "$PROJECT_DIR/.ralph-prompt"

    # Build QEMU arguments for dynamic 9p shares
    local qemu_extra_args=(
        "-virtfs" "local,path=$PROJECT_DIR,mount_tag=project,security_model=mapped-xattr"
        "-virtfs" "local,path=$HOME/.gitconfig,mount_tag=gitconfig,security_model=none,readonly=on"
        "-virtfs" "local,path=$HOME/.anthropic,mount_tag=anthropic,security_model=none,readonly=on"
    )

    # Export for extraArgsScript to use
    export MICROVM_EXTRA_ARGS="${qemu_extra_args[*]}"

    # Run the MicroVM
    local exit_code=0
    nix run "$FLAKE_DIR#claude-sandbox" 2>&1 | tee "$session_log" || exit_code=$?

    rm -f "$PROJECT_DIR/.ralph-prompt"

    return $exit_code
}

handle_exit_code() {
    local code="$1"
    case $code in
        0)
            log "Session completed successfully (exit 0). Restarting..."
            ntfy "Ralph session completed (exit 0)" low
            sleep 5
            ;;
        1)
            log "Context exhausted or planned exit (exit 1). Restarting..."
            ntfy "Ralph session: context exhausted, restarting" low
            sleep 10
            ;;
        2)
            # Rate limited — sleep and retry
            log "Rate limited (exit 2). Waiting 30 minutes..."
            ntfy "Ralph rate limited, waiting 30min" default
            sleep 1800
            ;;
        *)
            log "Unknown exit code ($code). Stopping."
            ntfy "Ralph unknown error (exit $code). Stopping." high
            exit 1
            ;;
    esac
}

main() {
    log "=== Ralph Loop (Sandboxed) Starting ==="
    log "Project: $PROJECT_DIR"
    log "Flake: $FLAKE_DIR"
    ntfy "Ralph loop starting (sandboxed)" low

    while true; do
        check_stop_file

        local exit_code=0
        run_sandboxed_session || exit_code=$?

        handle_exit_code "$exit_code"
    done
}

main "$@"
