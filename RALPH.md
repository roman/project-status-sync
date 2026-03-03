# Ralph Mode (Headless Operation)

You are running in **ralph loop mode** — an autonomous headless session inside a sandboxed
MicroVM. This file contains instructions specific to this execution context.

## Environment

- **Isolation**: You are in an ephemeral NixOS VM. Only `/project` is shared with the host.
- **No credentials**: `~/.ssh`, `~/.aws`, and other host directories are NOT mounted.
- **Read-only config**: `~/.gitconfig` and `~/.anthropic` are mounted read-only.
- **VM destroyed after exit**: Any files outside `/project` are lost.

## Startup Checklist

1. Read `/project/.ralph-prompt` for your task instructions
2. Check `/project/.msgs/` for messages from human
3. Read `/project/WORKPLAN.md` for current state
4. Resume from where the previous session left off

## During Session

- Work autonomously through WORKPLAN.md phases
- Commit frequently with focused messages (why, not what)
- Update `progress.log` after completing chunks
- Keep sessions short and focused (1-2 good commits)

## Before Context Exhaustion (~15% remaining)

1. Update WORKPLAN.md:
   - Phase progress checkboxes
   - Handoff notes for current phase
   - Session log entry
2. Append to `progress.log`
3. Commit all changes
4. Exit cleanly (the loop will restart you)

## Message Inbox

Check `/project/.msgs/` on startup and periodically.

- Human leaves messages as `.msgs/YYYYMMDD-HHMMSS-topic.md`
- Reply by creating `.msgs/YYYYMMDD-HHMMSS-re-topic.md`
- Delete messages after reading/responding

## Exit Codes

- **0**: Normal completion, loop restarts
- **1**: Context exhausted, loop restarts
- **2**: Rate limited, loop waits then restarts
- **Other**: Error, loop stops

## Stop Signal

If `/project/.ralph-stop` exists, the loop will exit after the current session completes.
Create this file from outside the VM to stop the loop gracefully.

## Debugging

If things go wrong:
1. Check `/tmp/claude-ralph-loop/loop.log` on the host
2. Session logs are in `/tmp/claude-ralph-loop/session-*.log`
3. Create `.ralph-stop` to pause and investigate
