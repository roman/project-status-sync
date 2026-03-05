# Haskell Development Skill

**Date**: 2026-03-04
**Session**: 1f73858f

## What Was Done

Created a Claude Code skill providing Haskell development conventions based
on the RIO library. The skill triggers when agents work on `.hs` files and
provides "do this, not that" guidance.

## Files Created

- `nix/packages/haskell-development-skill/SKILL.md` — core guidelines (14 sections)
- `nix/packages/haskell-development-skill/references/examples.md` — ~15 BAD/GOOD code pairs
- `nix/packages/haskell-development-skill/default.nix` — Nix package derivation
- `nix/modules/home-manager/haskell-development-skill/default.nix` — home-manager module
- `nix/modules/devenv/haskell-development-skill.nix` — devenv module (fourmolu + hlint + git-hooks)

## Files Modified

- `nix/devenvs/default.nix` — imports new devenv module

## Research

- RIO library conventions: https://github.com/commercialhaskell/rio
- Genvalidity testing patterns from NorfairKing/mergeful and NorfairKing/mergeless
- Devenv git-hooks integration from cachix/devenv

## Key Decisions

- **Fourmolu over Ormolu**: configurable (supports `.fourmolu.yaml`), 4-space indent
- **Genvalidity over raw QuickCheck**: validity-aware generation and shrinking,
  `producesValid` combinator for asserting function output validity
- **Error handling**: detectable errors as Maybe/Either, IO failures propagate as
  exceptions (only catch at business logic level when recovery is meaningful)
- **Style**: let-in preferred over where (let/in on own lines), point-free preferred

## Portability

The skill is exported as:
- `packages.<system>.haskell-development-skill`
- `homeManagerModules.haskell-development-skill`

Other flakes can consume it as a flake input. Can be moved to a standalone
flake later without changes to the skill content.

## Verification

```bash
nix build .#haskell-development-skill
ls result/share/claude/skills/haskell-development-skill/  # SKILL.md, references/

nix develop --impure
which fourmolu  # available
which hlint     # available
# git-hooks auto-installed for fourmolu + hlint
```
