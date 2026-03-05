# RALPH Scripts Audit & Overhaul

**Date**: 2026-03-04
**Session**: 5e01e56b

## What Was Done

### Audit
Full audit of RALPH.md revealed it was written for the abandoned MicroVM approach
(Infra.4) while the actual runtime uses bubblewrap. Identified 9 issues including
wrong environment descriptions, missing test gates, stale references, and no loop runner.

### RALPH.md Rewrite
- Replaced all MicroVM/VM references with bubblewrap sandbox reality
- Added `cabal test` gate before commits
- Added design gate: tasks introducing new public types/data formats write proposals
  to `notes/proposals/` and create `.ralph-stop` for human review
- Added code-critic review step: spawn code-critic agent after implementation,
  address blocker/major issues, cap at 2 review rounds
- Updated message inbox to reqID protocol (`<id>.md` → `<id>.reply.md`)
- Fixed debugging paths to project-local `tmp/` directory

### Script Suite
- Renamed `scripts/ralph-test.sh` → `scripts/ralph-oneshot.sh`
- Created `scripts/ralph-msg.sh` — send messages to running agent, poll for reply
- Created `scripts/ralph-loop.sh` — loop runner with exit code handling
  (0/1=restart, 2=wait 60s, other=stop, `.ralph-stop`=break)
- All logs now go to project-local `tmp/` (gitignored)
- DEFAULT_PROMPT simplified: points to RALPH.md as single source of behavioral instructions

### CLAUDE.md
- Removed stale "(RALPH.md to be created)" note
- Updated Ralph Mode section description

## Design Decision
Considered a full 5-phase coordinator with sub-agent orchestration (plan agents,
grug-architect, socratic-naming, super-coder, code-critic). After Opus review,
chose simpler approach: 5-line design gate in RALPH.md + single code-critic review
post-implementation. Same guardrails, fraction of the token cost.

## Files Changed
- `RALPH.md` — full rewrite
- `CLAUDE.md` — stale reference fix
- `scripts/ralph-oneshot.sh` — renamed from ralph-test.sh, updated prompt + log path
- `scripts/ralph-loop.sh` — new
- `scripts/ralph-msg.sh` — new
- `.ralph-prompt` — simplified
- `.gitignore` — added `tmp/`
- `notes/proposals/.gitkeep` — new directory
