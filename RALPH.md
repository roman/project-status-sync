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
4. Read the 3 most recent handoffs in `notes/handoffs/`
5. Read the last 10 lines of `progress.log`
6. **Run triage** — see Session Triage below

## Session Triage (MANDATORY)

Before doing any work, determine what role this session should take.

Spawn a `product-owner` agent (via the Task tool) with:
- The contents of WORKPLAN.md
- The most recent handoff document
- The last 10 lines of progress.log
- The contents of `.ralph-prompt`

The agent must answer three questions:
1. **Role**: one of `pm`, `architect`, `implementer`, `reviewer`
2. **Rationale**: 1-2 sentences explaining why this role, not another
3. **Scope**: specific items to work on this session

### Role Selection Criteria

| Signal in handoff/WORKPLAN | Assign |
|----------------------------|--------|
| Phase statuses don't match handoff reality | **pm** |
| WORKPLAN checkboxes are stale or inaccurate | **pm** |
| Design docs noted as outdated by handoff | **pm** |
| Domain decision flagged but not yet proposed | **architect** |
| Pending proposal needs writing | **architect** |
| Task introduces new public types/data formats | **architect** |
| Clear implementation chunk, WORKPLAN current, no blockers | **implementer** |
| Implementation complete, quality gate or review needed | **reviewer** |

When ambiguous, prefer **pm** — a current WORKPLAN is more valuable than more code.

## Role Protocols

### PM

Reconcile project state. No feature code.

1. Update WORKPLAN.md phase statuses to match reality
2. Update progress checkboxes per handoff evidence
3. Update design.md if handoffs flag it as outdated
4. Flag any gaps or missing handoff documents
5. Add pending items discovered during reconciliation
6. Commit: WORKPLAN.md + design.md + progress.log entry
7. Do NOT load haskell-development-skill or write Haskell code

### Architect

Elevate domain decisions into proposals. No implementation.

1. Spawn `grug-architect` agent with the `design-in-practice` skill to explore the design space and draft the proposal
2. Write proposal to `notes/proposals/YYYY-MM-DD-topic.md`
   - State the decision clearly
   - List options with trade-offs (use a Decision Matrix for non-trivial choices)
   - Recommend one option with rationale
2. Spawn `code-critic` agent to review the proposal (clarity, completeness, trade-off coverage)
3. Update WORKPLAN.md: add blocked item referencing proposal
4. Commit the proposal + WORKPLAN update + progress.log entry
5. Create `.ralph-stop` and exit — human reviews proposal before work proceeds

### Implementer

Write code. This is the only role that touches `src/` or `app/`.

1. Load `haskell-development-skill` via Skill tool
2. Verify: WORKPLAN is current, no blocking proposals
3. Implement the next chunk from WORKPLAN
4. Run `cabal test` — do not proceed if tests fail
5. Spawn `code-critic` agent to review changes (max 2 rounds)
6. Commit: code + WORKPLAN update + progress.log + handoff doc

### Reviewer

Assess quality. No fixes — findings go to next session.

1. Spawn `code-critic` for full codebase review
2. Spawn `product-owner` to assess WORKPLAN alignment
3. Write findings to handoff document
4. Update WORKPLAN with any issues discovered
5. Commit: handoff + WORKPLAN + progress.log entry
6. Do NOT implement fixes (next session handles them)

## Decision Protocol

When **any role** encounters a domain modelling decision during work, STOP and
switch to the Architect protocol. Do not make the decision inline.

Domain decisions include:

- Introducing `Maybe`/`Optional` in domain types
- Sum type constructors exceeding 3 positional fields
- Changing data flow between modules
- New public types other modules depend on
- Switching established patterns (e.g. record-event → stdout parsing)
- Adding new dependencies between modules

The proposal in `notes/proposals/` is reviewed via council loop (human-initiated)
before implementation proceeds.

## During Session

- Keep sessions short and focused (1-2 good commits)
- Commit frequently with focused messages (why, not what)
- Update `progress.log` after completing chunks
- Run `cabal test` before every commit that touches code
- Follow the protocol for your assigned role — do not drift into another role's work

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
