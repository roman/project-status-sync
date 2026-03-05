# Fix: Haskell Development Skill Devenv Module

**Date**: 2026-03-04
**Session**: 096d828d

## Problem

The haskell-development-skill devenv module only installed tools (fourmolu, hlint) and
configured git hooks, but never wrote the skill files (SKILL.md, references/) into
`.claude/skills/`. Claude Code couldn't discover the skill at session start.

## Solution

Adopted the `mkSkillFiles` pattern from nixDir's nixdir-skill devenv module:

1. **Module structure**: Converted from simple config to proper NixOS module with
   `options`/`config` pattern and `claude.code.plugins.haskell-development.enable` option
2. **Package reference**: Uses `inputs.self.packages.${pkgs.system}.haskell-development-skill`
   to reference the built package
3. **File installation**: `mkSkillFiles` reads package contents from the Nix store and
   declares them as devenv `files.*` entries, which get symlinked into `.claude/skills/`
4. **Module args**: `inputs` is passed to modules via `_module.args = { inherit inputs; }`
   in the devenv shell definition

## Key Discovery

nixDir's `importWithInputs = true` only applies the curried `inputs:` prefix for
configurations (nixos/darwin), NOT for modules. Modules in `nix/modules/devenv/` are
always imported with plain `import` (no inputs). To access `inputs`, pass it via
`_module.args` from the devenv shell definition.

## Files Changed

- `nix/modules/devenv/haskell-development-skill.nix` — Full rewrite with options/config pattern
- `nix/devenvs/default.nix` — Added `_module.args` and enabled the plugin
