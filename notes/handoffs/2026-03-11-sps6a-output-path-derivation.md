# Handoff: S.PS.6a — Output Path Derivation with Mappings

**Date**: 2026-03-11
**Session**: 060bb90d
**Role**: Implementer

## What Was Done

Added `OrgMappings`, `ProjectOverrides` newtypes and `deriveOutputSubpath`
function to `CCS.Project`. These enable configurable output directory paths
for multi-org setups where projects from different git hosts need organizational
context in their output paths.

Logic: override (exact match) > org mapping (longest prefix) > fallback (last path component).

Edge case handled: when project key exactly equals an org mapping prefix,
falls back to `deriveName` rather than producing a trailing-slash path.

Files changed:
- `src/CCS/Project.hs`: new types + function + helpers
- `test/Main.hs`: 9 unit tests + 2 property tests (90 total, all pass)

## Spec Compliance

WORKPLAN item: "S.PS.6a: Library — output path derivation with mappings"
- Approved proposals checked: `2026-03-08-process-config-prompt-fields.md` — affects ProcessConfig, not Project. No conflicts.
- `OrgMappings` newtype over `Map Text Text`: met
- `ProjectOverrides` newtype over `Map Text Text`: met
- `deriveOutputSubpath :: ProjectKey -> OrgMappings -> ProjectOverrides -> FilePath`: met
- Check projectOverrides first (exact match on key): met
- Check orgMappings (longest prefix match): met
- Fallback to deriveName: met
- Tests — prefix matching: met
- Tests — override priority: met
- Tests — fallback: met
- Tests — overlapping prefixes: met

## Code Critic Findings

No blockers. One major finding (trailing slash on exact prefix match) was
fixed by adding a guard when `trimmed` is empty. Test added for coverage.

## What's Next

- S.PS.6b: CLI — add `--org-mapping` and `--project-override` flags to `ccs aggregate`
- S.PS.6c: Nix module — wire options to CLI flags
