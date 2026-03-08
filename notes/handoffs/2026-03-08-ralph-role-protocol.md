# Handoff: Ralph Role-Based Triage Protocol

**Date**: 2026-03-08
**Session**: 821f18cf

## What Was Done

Analyzed the `3732bb51` ralph session and identified three process gaps:

1. **No PM gate** — WORKPLAN drifted because no session prioritized reconciliation
2. **No decision protocol** — `Maybe` types added to `ProcessConfig` without proposal
3. **No role routing** — every session was an implementer regardless of handoff state

Implemented role-based triage protocol:

- Updated `RALPH.md` with triage step (product-owner agent determines session role)
- Four roles defined: PM, Architect, Implementer, Reviewer
- Expanded decision protocol: domain decisions (Maybe in ADTs, >3 positional fields,
  pattern switches) trigger proposal workflow instead of inline execution
- Updated `CLAUDE.md` universally: skill loading is a code-writing gate (not startup),
  code-critic review scoped to code commits, doc tiers per commit type
- Reconciled WORKPLAN.md: Phase 2c PARTIAL (2c.1 done), Phase 3 PARTIAL (3.1+3.2 done)
- Added pending items: AggregateConfig extraction, Maybe-in-ProcessConfig proposal,
  design.md stdout-parsing update

## What's Next

- Architect session: write proposal for `Maybe FilePath` in `ProcessConfig`
- Implementer session: extract `AggregateConfig` record from `AggregateCmd`
- Implementer session: update `docs/design.md` to reflect stdout-parsing approach
- Test triage protocol: run a ralph loop and verify PM role is assigned when WORKPLAN is stale

## Notes

- The `notes/proposals/` directory already existed but was unused
- CLAUDE.md changes are universal (apply to interactive + ralph sessions)
- Triage agent should be `product-owner` type, not `general-purpose`
