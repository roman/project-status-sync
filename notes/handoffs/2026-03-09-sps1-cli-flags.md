# Handoff: S.PS.1 CLI flags for project-status-sync

**Date**: 2026-03-09
**Session**: ralph-headless
**Role**: Implementer

## What Was Done

Added `--llm-command`, `--llm-arg`, and `--prompts-dir` flags to `ccs aggregate`.
Bundled prompts in the ccs Nix package at `$out/share/ccs/prompts/`.

These flags are the runtime prerequisite for the S.PS.2 home-manager module, which
already generates service commands referencing them.

Key implementation details:
- `--llm-command CMD` defaults to `claude`; wired to `pcCommand` in ProcessConfig
- `--llm-arg ARG` is repeatable via `many`; defaults to `["-p"]` when none given
- `--prompts-dir DIR` resolves conventional filenames (`session-extraction.md`, etc.)
- Individual `--prompt-file`, `--handoff-prompt`, etc. are now optional overrides
  that take precedence over `--prompts-dir`
- `resolvePrompt` helper: override > directory > error with clear message
- Nix package uses `overrideAttrs` with `postInstall` to copy prompts

Files changed:
- `app/Main.hs`: AggregateConfig fields, parser, resolvePrompt helper
- `nix/packages/ccs/default.nix`: overrideAttrs to bundle prompts

Files NOT changed:
- `src/CCS/Process.hs`: already had `pcCommand`/`pcCommandArgs` fields

## Spec Compliance

WORKPLAN item: "S.PS.1: CLI changes"

- Approved proposals checked: `2026-03-08-process-config-prompt-fields.md` (Option B: All Mandatory) — not affected, ProcessConfig keeps `!FilePath` fields, Maybe only in CLI layer
- `--llm-command CMD` flag (default: `claude`): met
- `--llm-arg ARG` repeatable flag (default: `-p`): met
- `--prompts-dir DIR` flag with conventional filenames: met
- Individual flags as overrides: met
- Bundle prompts in Nix package: met
- Wire into ProcessConfig: met

## Code Critic Findings

No blockers or major issues. Two minor suggestions about help-text clarity (not addressed — not blocking).

## What's Next

- S.PS.3: Deprecate ccs-session-end-hook module
- S.PS.4: Integration in zoo.nix
- S.PS.5: Verification (mechanical checks unblocked)
