# Handoff: Aggregation Job Skeleton

**Date**: 2026-03-06
**Session**: 36006ba6

## What Was Done

- Created `CCS.Aggregate` module with:
  - `SessionId`, `AvailabilitySignal`, `AggregateResult` types
  - `discoverSignals` — finds `.available` files, parses into enriched signals
  - `isQuietPeriodElapsed` — pure quiet period check against newest signal mtime
  - `withLockFile` — advisory file locking via `hTryLock` (no delete, avoids TOCTOU)
  - `consumeSignal` — deletes processed signal files
  - `runAggregation` — orchestrates discovery → quiet check → lock → process → consume
- Wired `ccs aggregate --signal-dir DIR --quiet-minutes N` CLI command
- Added `hp.rio` and `hp.process` to devenv haskellDeps (sandbox build fix)
- Tests for all public functions (quiet period, discovery, locking, consumption)

## What's Next

- Build verification outside sandbox (rio missing from GHC package set)
- Phase 2c: wire real processing (invoke `claude -p` with extraction prompt)

## Notes

- Sandbox can't build: `rio` was never in devenv's `haskellDeps`, relied on cabal downloading from Hackage. Fixed by adding `hp.rio` + `hp.process`.
- Lock file uses advisory locking (`hTryLock`), file persists as sentinel to avoid TOCTOU race.
- Signal timestamp uses file mtime (design decision from docs/design.md).
