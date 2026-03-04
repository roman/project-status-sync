# RALPH Sandbox Exploration — Handoff

**Date**: 2026-03-03 (updated 2026-03-03 session 11)
**Session**: Security analysis and sandbox implementation for RALPH loops
**Status**: WORKING — headless sandbox fully functional after Claude Code update

## Context

User wanted to run RALPH loops (autonomous Claude sessions) safely. Concerned about `--dangerously-skip-permissions` granting full access to ~/.ssh, ~/.aws, etc.

## What We Did

### 1. Security Risk Analysis
- Documented risks of unsandboxed RALPH (credential theft, project access, network exfiltration)
- Compared container alternatives (bubblewrap, firejail, systemd-nspawn, podman)

### 2. Found bubblewrap-claude
- Existing Nix flake: `github:matgawin/bubblewrap-claude`
- Uses bwrap for filesystem isolation + Squid proxy for network domain filtering
- Only allows `api.anthropic.com` — blocks exfiltration to other domains
- Cloned to: `~/Projects/oss/bubblewrap-claude`

### 3. Tested Isolation — WORKS
```
✅ ~/.ssh blocked (not mounted)
✅ ~/.aws blocked (not mounted)
✅ ~/Projects blocked (only project dir mounted)
✅ Network filtered (only api.anthropic.com allowed via Squid)
✅ Project read/write works
```

### 4. Added Headless Mode
Modified local clone to support `-p` mode for RALPH:
- `lib/sandbox/default.nix` — added `makeHeadlessSandboxScript`
- `lib/default.nix` — exported `mkHeadlessSandbox`
- `flake.nix` — added `claude-headless` and `claude-headless-{profile}` packages
- Reads prompt from `.ralph-prompt` file, runs `claude -p`

### 5. Tested Headless — WORKS (after Claude Code update)

Previous session (session 10) saw tool execution failures in `-p` mode.
Root cause: **Claude Code version bug**, fixed in v2.1.59+.

After updating Claude Code, all tool types work in the sandbox:
```
✅ Write tool — single file creation
✅ Read + Write — multi-turn tool chains
✅ Bash tool — ls, git init, git commit, etc.
✅ Multi-step prompts — 3+ tool calls in sequence (read → write → bash)
✅ Git operations — init, add, commit, log
```

### 6. Network Isolation Verified
```
✅ WebFetch/WebSearch — blocked by --disallowedTools
✅ curl/wget via Bash — blocked by --disallowedTools pattern
✅ Raw TCP (/dev/tcp) — blocked by DNS (resolv.conf → bogus 192.0.2.1)
✅ No python/node/wget in sandbox PATH
✅ API calls — work via Squid proxy (only api.anthropic.com allowed)
```

### 7. Fixed Stale Proxy Cleanup
The squid proxy would orphan when the wrapper process was killed externally
(SIGKILL). Next run would hang because of leftover processes.

Fix in `lib/proxy/default.nix`:
- Write squid PID to `/tmp/claude-sandbox-proxy/squid.<ppid>.pid`
- On startup, scan for and kill stale squid processes from previous runs
- Normal cleanup trap still fires on graceful exit

## Files Modified

```
~/Projects/oss/bubblewrap-claude/
├── lib/sandbox/default.nix    # Added makeHeadlessSandboxScript
├── lib/default.nix            # Exported mkHeadlessSandbox
├── lib/proxy/default.nix      # Stale squid cleanup on startup
└── flake.nix                  # Added claude-headless packages
```

Changes NOT committed (dirty working tree in bubblewrap-claude).

## Files Created in This Project

```
~/Projects/self/claude-conversation-sync/
├── scripts/ralph-sandboxed.sh  # Manual bwrap wrapper (abandoned)
└── .ralph-prompt               # Test prompt file
```

## Key Commands

```bash
# Build headless sandbox
cd ~/Projects/oss/bubblewrap-claude
nix build .#claude-headless

# Run headless sandbox (mounts $PWD as project dir)
echo 'Your prompt here' > .ralph-prompt
env -u CLAUDECODE ./result/bin/claude-headless .

# Run with specific project directory
env -u CLAUDECODE ./result/bin/claude-headless /path/to/project

# Monitor a run (session files appear here)
ls -lt ~/.claude/projects/-home-roman-project/*.jsonl

# Check session progress
tail -1 <session>.jsonl | jq -r '.type // .message.role'
```

## Monitoring Script

Use this script to run the sandbox with progress reporting. It watches
the session JSONL for activity and enforces a timeout. Essential for
debugging — if no session file appears within 10s, something is stuck
at startup (not the API call).

```bash
#!/usr/bin/env bash
set -euo pipefail

PROMPT="$1"
PROJECT_DIR="${2:-.}"
TIMEOUT="${3:-60}"
SESSION_DIR="$HOME/.claude/projects/-home-roman-project"

echo "$PROMPT" > "$PROJECT_DIR/.ralph-prompt"

# Snapshot existing sessions
BEFORE=$(ls "$SESSION_DIR"/*.jsonl 2>/dev/null | sort)

# Launch sandbox in background
cd "$PROJECT_DIR"
env -u CLAUDECODE ~/Projects/oss/bubblewrap-claude/result/bin/claude-headless . > /tmp/sandbox-output.log 2>&1 &
SANDBOX_PID=$!

echo "Sandbox PID: $SANDBOX_PID"
echo "Timeout: ${TIMEOUT}s"
echo "---"

for i in $(seq 1 "$TIMEOUT"); do
    sleep 1

    # Check if process is still alive
    if ! kill -0 "$SANDBOX_PID" 2>/dev/null; then
        wait "$SANDBOX_PID" 2>/dev/null
        EXIT=$?
        echo "[${i}s] Process exited (code: $EXIT)"
        echo "=== Output ==="
        cat /tmp/sandbox-output.log
        exit $EXIT
    fi

    # Every 5s, report status
    if (( i % 5 == 0 )); then
        # Check for new session file
        AFTER=$(ls "$SESSION_DIR"/*.jsonl 2>/dev/null | sort)
        NEW_SESSION=$(comm -13 <(echo "$BEFORE") <(echo "$AFTER") | tail -1)

        if [ -n "$NEW_SESSION" ]; then
            LINES=$(wc -l < "$NEW_SESSION")
            LAST_TYPE=$(tail -1 "$NEW_SESSION" | jq -r '.type // .message.role // "unknown"' 2>/dev/null)
            echo "[${i}s] Session: $(basename "$NEW_SESSION") lines=$LINES last=$LAST_TYPE"
        else
            # Check what processes exist
            PROCS=$(ps --ppid "$SANDBOX_PID" -o comm= 2>/dev/null | tr '\n' ',' || echo "none")
            echo "[${i}s] No session file yet. Children: $PROCS"
        fi
    fi
done

echo "[${TIMEOUT}s] TIMEOUT — killing"
kill -9 "$SANDBOX_PID" 2>/dev/null
echo "=== Output so far ==="
cat /tmp/sandbox-output.log
exit 1
```

Usage:
```bash
# Basic: 60s timeout
bash run-and-monitor.sh 'Read foo.txt and create bar.txt' /path/to/project

# Custom timeout
bash run-and-monitor.sh 'Do complex task' /path/to/project 120

# Example output:
# Sandbox PID: 63606
# Timeout: 90s
# ---
# [5s] Session: c953c680-....jsonl lines=7 last=user
# [10s] Session: c953c680-....jsonl lines=11 last=user
# [15s] Session: c953c680-....jsonl lines=14 last=assistant
# [20s] Process exited (code: 0)
# === Output ===
# Done. All three tasks completed.
```

## Lessons Learned

1. **"Hanging" sandbox was actually orphaned processes** — when a parent Bash
   tool call gets canceled, child processes (squid, bwrap) survive. Next runs
   appear to hang but are blocked by stale processes, not the sandbox itself.

2. **Always monitor session JSONL for progress** — if no session file appears
   within 10s, something is stuck at startup (not the API call).

3. **Claude Code version matters** — v2.1.59+ fixed `-p` mode tool execution.
   Previous versions had permission system bugs that blocked tools even with
   `--dangerously-skip-permissions`.

## Next Steps

1. **Commit bubblewrap-claude changes** — headless mode + proxy cleanup fix
2. **RALPH-style integration test** — realistic multi-step coding task
3. **Wire into CCS** — use sandbox for automated session processing (Phase 2c)
