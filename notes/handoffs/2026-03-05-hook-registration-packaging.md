# Handoff: Hook Registration Packaging

**Date**: 2026-03-05
**Phase**: 1.4a, 1.4b

## What Was Done

### 1.4a: Package the hook script

- Created `nix/packages/ccs-session-end-hook/default.nix` using `writeShellApplication`
- Runtime dep: `jq` (added to PATH automatically via `runtimeInputs`)
- Exported as `packages.<system>.ccs-session-end-hook` via nixDir auto-discovery

### 1.4b: Home-manager module

- Created `nix/modules/home-manager/ccs-session-end-hook/default.nix`
- Option namespace: `programs.claude-code.plugins.conversation-sync`
- Sets `programs.claude-code.settings.hooks.SessionEnd` hook entry
- Optional `signalDir` option to override `CCS_SIGNAL_DIR`
- Follows the same pattern as the haskell-development-skill module

## What's Next

- 1.4c verification: `nix build .#ccs-session-end-hook` must succeed on host
- Verify built script has `jq` on PATH
- Manual test: pipe JSON to hook and check signal file created
- Import in consuming flake and verify `settings.json` gets SessionEnd entry

## Notes

- No nix tools in sandbox, so build not verified
- Pattern follows beads: standalone package + home-manager module
