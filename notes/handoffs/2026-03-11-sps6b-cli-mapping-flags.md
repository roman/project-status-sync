# Handoff: S.PS.6b — CLI Mapping Flags

**Date**: 2026-03-11
**Role**: Implementer

## What Was Done

Added `--org-mapping KEY=VALUE` and `--project-override KEY=PATH` repeatable
CLI flags to `ccs aggregate`. These flags thread `OrgMappings` and
`ProjectOverrides` from CLI through `AggregateConfig` → `ProcessConfig` →
`processSession`, where `deriveOutputSubpath` replaces the previous hardcoded
`deriveName` path derivation.

Files changed:
- `app/Main.hs`: new fields in `AggregateConfig`, `parseKeyValue` helper,
  `maybeReader` import, threading to `ProcessConfig`
- `src/CCS/Process.hs`: new `pcOrgMappings`/`pcProjectOverrides` fields,
  import of `deriveOutputSubpath`, replaced `T.unpack pname` with
  `deriveOutputSubpath` call
- `ccs.cabal`: added `text` to executable build-depends (for `Data.Text.breakOn`)

## Spec Compliance

WORKPLAN item: "S.PS.6b: CLI — new flags"
- Approved proposals checked: `2026-03-08-process-config-prompt-fields.md` — affects prompt fields only, no conflict with new mapping fields
- `--org-mapping KEY=VALUE` repeatable flag: met
- Parsed as Text split on first `=`: met (via `breakOn`)
- `--project-override KEY=PATH` repeatable flag: met
- `acOrgMappings` and `acProjectOverrides` in `AggregateConfig`: met
- Thread through to `ProcessConfig` and `processSession`: met

## Code Critic Findings

No blockers. Clean, minimal implementation (~15 lines new code in Main.hs,
~3 lines changed in Process.hs). `parseKeyValue` correctly handles `KEY=VAL=UE`
(splits on first `=` only) and rejects empty keys/values.

## What's Next

- S.PS.6c: Nix module — wire `orgMappings` and `projectOverrides` options to CLI flags
