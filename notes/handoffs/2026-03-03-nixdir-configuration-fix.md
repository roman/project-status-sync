# nixDir Configuration Fix Handoff

**Date**: 2026-03-03
**Session**: f0a66dbb
**Phase**: Infra.4 maintenance

## Summary

Migrated the microvm configuration to use nixDir's auto-discovery for NixOS
configurations. This required fixing a bug in nixDir where the `importWithInputs`
option wasn't being applied to flake-level configuration files.

## Changes Made

### claude-conversation-sync

1. **Moved configuration to nixDir-compliant location**:
   - From: `nix/microvm/claude-sandbox.nix`
   - To: `nix/configurations/nixos/claude-sandbox/`
     - `default.nix` — nixDir entry point: `inputs: { system, modules }`
     - `configuration.nix` — NixOS module with microvm config

2. **Simplified flake.nix**:
   - Removed manual `flake = { nixosConfigurations = ... }` block
   - nixDir now auto-discovers the configuration

### nixDir (local clone at ~/Projects/nixDir)

**Commit**: b91b644 on v3 branch (pushed to github:roman/nixDir)

**Bug**: The `addFlakeLevelOutput` function was hardcoding `withInputs = false` for
the regular path, ignoring `cfg.importWithInputs`. This meant configuration files
couldn't use the `inputs: { system, modules }` signature.

**Fix**: Only apply `importWithInputs` to configurations (not modules), since
modules receive inputs via the standard NixOS module system's `specialArgs`.

```nix
# Only configurations respect importWithInputs for the regular path.
# Modules use the standard module system which injects inputs via specialArgs.
isConfiguration = kindName == "nixosConfigurations" || kindName == "darwinConfigurations";
useInputsForRegular = isConfiguration && cfg.importWithInputs;

regular = if builtins.pathExists regularPath
  then importKind regularPath useInputsForRegular
  else { };
```

## Verification

```bash
# Test configuration evaluates correctly
nix eval .#nixosConfigurations.claude-sandbox.config.networking.hostName
# Returns: "claude-sandbox"

# Test microvm runner package
nix eval .#packages.x86_64-linux.claude-sandbox.name
# Returns: "microvm-qemu-claude-sandbox"
```

## Status

- nixDir fix pushed to github:roman/nixDir v3 branch
- flake.lock updated to use the fixed version
