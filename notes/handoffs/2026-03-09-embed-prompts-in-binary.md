# Embed Prompts in Binary via file-embed

**Date**: 2026-03-09
**Session**: ced1cc00

## Summary

Replaced runtime prompt file resolution with compile-time embedding via
`file-embed`. The binary is now self-contained — no `--prompts-dir` flag or
`$out/share/ccs/prompts/` directory needed.

## What Changed

1. **New `app/Prompts.hs`**: Four TH splices embed prompt files at compile time
2. **`ProcessConfig` fields**: `FilePath` → `Text` (prompt content, not paths)
3. **`runLLMPrompt`**: Receives prompt `Text` directly, no file I/O
4. **CLI**: `--prompts-dir` removed; `--prompt-file` renamed to `--extraction-prompt`;
   all four prompt flags are optional overrides (default: embedded)
5. **Nix package**: Removed `postInstall` that copied prompts to `$out/share/ccs/prompts/`
6. **Home-manager module**: Removed `--prompts-dir` from generated service command

## Spec Compliance

WORKPLAN item: S.PS.1 (embed prompts, simplify CLI)

- Embedded prompts via file-embed: met
- Optional CLI overrides preserved: met
- --prompts-dir removed: met
- Nix prompt bundling removed: met
- ProcessConfig FilePath→Text: met (all 4 call sites updated)

## Verification

- `cabal build` — clean, no warnings
- `cabal test` — 79/79 tests pass
- `ccs aggregate --help` — confirms new CLI surface
- Code critic review: no blocker/major issues

## Next Steps

- S.PS.3: Deprecate ccs-session-end-hook module
- S.PS.4: Integration in zoo.nix
- S.PS.5: Verification (mechanical + quality)
