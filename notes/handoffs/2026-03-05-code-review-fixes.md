# Code Review Fixes

**Date**: 2026-03-05
**Session**: 8fbc4425
**Phase**: Post-Phase 1 cleanup

## Context

Ran code-critic agent against the Haskell codebase. Found 16 issues across
safety, correctness, housekeeping, and observability. Fixing all of them in
focused commits.

## Changes Made

### 1. normalizeRemoteUrl: T.stripPrefix instead of magic numbers
- Replaced `T.drop N` with `T.stripPrefix` pattern matching
- Eliminates bug class where scheme length integer drifts from prefix string
- Renamed `normalizeSchemeUrl` → `normalizeAfterScheme` (no longer takes Int)
- Switched `RIO.Text` → `Data.Text` (RIO.Text doesn't export breakOn/breakOnEnd)

### 2. Signal.hs: strict IO + atomic writes
- `readSignal`: lazy `LBS.readFile` → strict `BS.readFile` + `eitherDecodeStrict'`
- `writeSignal`: direct `LBS.writeFile` → temp file + `renameFile` (atomic on POSIX)
- Prevents partial signal files visible to aggregation job

### 3. Version from Paths_ccs, cabal cleanup
- Use auto-generated `Paths_ccs.version` instead of hardcoded "0.1.0.0"
- Removed useless version test (tested constant against itself)
- Removed unused library deps: `optparse-applicative`, `time`
- Trimmed unused default-extensions: `BangPatterns`, `TupleSections`, `TypeFamilies`

### 4. Observability: stderr logging
- `gitCommand`: logs stderr on failure instead of silently discarding
- Shell hook: writes stderr warning when required fields missing

## What's Left

- Property tests for `normalizeRemoteUrl` (QuickCheck) — deferred to Phase 2a
- Deeper RIO integration (`RIO.Process`, `HasLogFunc`) — deferred until needed
