# Cabal Test Pre-commit Hook

**Date**: 2026-03-05
**Session**: 90973939
**Phase**: Supplementary (Tooling)

## What was done

Added a devenv module (`nix/modules/devenv/cabal-test.nix`) that registers a `cabal-test`
git pre-commit hook. Uses `lib.mapAttrs (_: lib.mkDefault)` following the same pattern as
upstream git-hooks.nix hook definitions.

## Key decisions

- **pre-commit stage** (not pre-push): runs tests before every commit
- **always_run = true**: tests run regardless of which files changed
- **pass_filenames = false**: `cabal test` operates on the whole project

## Known issue

One pre-existing test failure: `CCS.Filter` / `skips non-text blocks in array` (test/Main.hs:109).
To be resolved in a future session.

## Files changed

- `nix/modules/devenv/cabal-test.nix` — new module
- `nix/devenvs/default.nix` — imports module, enables hook
