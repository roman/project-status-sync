# Handoff: Add Haskell dev tools to bubblewrap sandbox

**Date**: 2026-03-05
**Session**: 9878df7a
**Phase**: Infra

## What Was Done

- Built custom `claude-headless-ccs` inline in devenv using `bubblewrap-claude.lib`
- `deriveProfile base` adds dev tools on top of the 28 base utilities
- Dev tools included: ghc (with all library deps), cabal, HLS, fourmolu, hlint, nixfmt
- Devenv remains single source of truth — `devTools` list feeds both shell and sandbox
- Verified bwrap `--setenv PATH` inside sandbox contains all tools

## Why

Two ralph sessions skipped `cabal test` because the default `claude-headless` had no
GHC/cabal. The pre-commit gate (`cabal test` before every commit) was unenforceable
in headless mode.

## Key Details

- `/nix` is bind-mounted read-only in the sandbox, so nix store paths work
- `wrapProgram --prefix PATH` in the wrapper is host-only; the real sandbox PATH is
  set by bwrap's `--setenv PATH` from `profile.packages`
- `ghcWithPackages haskellDeps` pre-builds all library deps, so cabal doesn't need
  network access to download packages

## What's Next

- Verify `cabal test` works in a real ralph session
- The `haskellDeps` list in devenv must stay in sync with `ccs.cabal` manually
