# Handoff: Signal Format & Project Identification

**Date**: 2026-03-05
**Phase**: 1.1, 1.2

## What Was Done

### Phase 1.1: Signal Format Definition

- Created `CCS.Signal` module with `SignalPayload` type and Aeson instances
- JSON schema: `{"transcript_path": "...", "cwd": "..."}`
- `readSignal`/`writeSignal` file I/O helpers
- JSON round-trip and decode tests in `test/Main.hs`
- Example signal file at `docs/examples/signal-available.json`

### Phase 1.2: Project Identification Module

- Created `CCS.Project` module with `ProjectKey`, `ProjectName`, `Project` types
- `identifyProject` shells out to git for remote URL and root path
- `normalizeRemoteUrl` handles SSH (SCP-style), ssh://, https://, http:// → `host/path`
- Monorepo support: appends relative subpath from git root to key
- Directory fallback for non-git projects (uses last path component)
- 9 unit tests for URL normalization (SSH/HTTPS equivalence, token auth, corporate hosts)

## Notes

- Build not verified in sandbox (no cabal/ghc available). Verify with
  `cabal build && cabal test` on host.
