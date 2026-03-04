# RALPH Test Script — Handoff

**Date**: 2026-03-03
**Session**: 0173e334
**Status**: Complete

## What Was Done

Created `scripts/ralph-test.sh` — a monitoring wrapper for running single RALPH sessions in the bubblewrap sandbox.

Features:
- Zombie process cleanup before launch (stale squid proxies, orphaned bwrap/claude processes)
- Session file monitoring every 5s (line count, last message type)
- Commit count diff on exit
- `.ralph-stop` detection and cleanup
- Timeout with forced kill (default 120s)
- Default prompt: one commit then stop

Also added `.ralph-prompt`, `.ralph-stop`, `.msgs/` to `.gitignore` since these are runtime artifacts.

## First Successful RALPH Run

The sandbox agent (session 12) autonomously:
- Read WORKPLAN.md, picked Phase 1.1
- Implemented `src/CCS/Signal.hs` with `SignalPayload` type
- Added JSON round-trip tests
- Created example signal file
- Updated WORKPLAN.md and progress.log
- Committed as `d5be23b`
- Created `.ralph-stop` and exited

## Key Finding

Session files land in `~/.claude/projects/-home-roman-project/` (not the real host path) because bwrap mounts the project at `~/project` inside the sandbox. The script accounts for this.

## Usage

```bash
nix develop --impure
./scripts/ralph-test.sh                          # default one-commit prompt
./scripts/ralph-test.sh 'custom prompt' 180      # custom prompt + timeout
```
