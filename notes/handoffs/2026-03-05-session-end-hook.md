# Handoff: SessionEnd Hook Script

**Date**: 2026-03-05
**Phase**: 1.3

## What Was Done

Created `scripts/session-end-hook.sh` — a fast shell script that Claude Code's
SessionEnd hook invokes. Reads JSON from stdin (`session_id`, `transcript_path`,
`cwd`), writes a `.available` signal file matching the `CCS.Signal.SignalPayload`
format. Signal directory defaults to `$XDG_STATE_HOME/ccs/signals/`, overridable
via `$CCS_SIGNAL_DIR`.

## What's Next

Phase 1.4: Hook registration via home-manager module — wire the script into
`~/.claude/settings.json` so Claude Code actually calls it on session end.

## Notes

- Script depends on `jq` being on `$PATH`
- No Haskell changes; build not verified in sandbox (no cabal/ghc)
- Silently exits on missing fields to keep hook latency near zero
