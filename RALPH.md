# Ralph Mode (Headless Operation)

You are running in **ralph loop mode** — an autonomous headless session inside a
bubblewrap sandbox. This file contains instructions specific to this execution context.

## Environment

- **Isolation**: You are in a bubblewrap (bwrap) user-namespace sandbox. Only the project
  directory is mounted read-write at `~/project`.
- **No credentials**: `~/.ssh`, `~/.aws`, and other host directories are NOT mounted.
- **Read-only config**: `~/.gitconfig` and `~/.anthropic` are mounted read-only.
- **Network filtered**: Only `api.anthropic.com` is reachable (via Squid proxy).
- **Ephemeral**: Anything outside the project directory is lost when the session ends.

## Startup Checklist

1. Read `.ralph-prompt` for your task instructions
2. Check `.msgs/` for messages from human (if the directory exists)
3. Read `WORKPLAN.md` for current state
4. Resume from where the previous session left off

## During Session

- Work autonomously through WORKPLAN.md phases
- **Before implementing**, briefly assess: does this task introduce new public types,
  data formats, or API shapes that other components will depend on? If yes, write the
  proposed type signatures and rationale to `notes/proposals/`, create `.ralph-stop`,
  commit the proposal, and exit. The human will review before work proceeds.
- **After implementing**, run `cabal test`. If tests pass, spawn a `code-critic` agent
  (via the Task tool) to review your changes. Address legitimate issues (blocker/major
  severity). Ignore stylistic nitpicks. Do not loop more than twice — ship it.
- **Run `cabal test` before every commit** — do not commit if tests fail
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

Check `.msgs/` on startup and periodically (if the directory exists).

- Messages arrive as `.msgs/<id>.md` where `<id>` is a short hex string (e.g. `a3f7b2c1`)
- Reply by creating `.msgs/<id>.reply.md` using the **same ID**
- Delete the original `.msgs/<id>.md` after replying
- The human's tooling polls for your `.reply.md` file, so write it promptly

## Exit Codes

- **0**: Normal completion, loop restarts
- **1**: Context exhausted, loop restarts
- **2**: Rate limited, loop waits then restarts
- **Other**: Error, loop stops

## Stop Signal

If `.ralph-stop` exists, create no more commits and exit immediately.
The loop runner (or human) creates this file to stop work gracefully.

## Debugging

If things go wrong:
1. Oneshot logs: `tmp/ralph-oneshot.log`. Loop logs: `tmp/ralph-loop-<N>.log`
2. Session JSONL files are in `~/.claude/projects/-home-roman-project/` on the host
3. Create `.ralph-stop` to pause and investigate
