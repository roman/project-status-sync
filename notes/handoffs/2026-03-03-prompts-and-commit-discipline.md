# Handoff: Prompts and Commit Discipline

**Date**: 2026-03-03
**Session**: 6 (no session tracking active)
**Continues from**: [2026-03-03-notes-repo-protocol-design.md](./2026-03-03-notes-repo-protocol-design.md)

## What Was Done

- Created three prompts for Notes repo protocol processing flow:
  - `prompts/handoff-generation.md` — creates session handoff from events
  - `prompts/progress-entry.md` — generates single-line progress.log entry
  - `prompts/status-synthesis.md` — synthesizes STATUS.md from EVENTS.jsonl
- Updated Phase 2b in WORKPLAN.md with new chunks (2b.3, 2b.4) and progress
- Strengthened CLAUDE.md with non-negotiable commit discipline:
  - Agents must read WORKPLAN.md before starting work
  - Every commit must include documentation updates (WORKPLAN, progress.log, handoffs)
  - Plans must be persisted to docs/plans/

## What's Next

From the Notes repo protocol plan (`docs/plans/2026-03-03-notes-repo-protocol-design.md`):

1. Update `docs/design.md` with Notes repo architecture
2. Implement project key → Notes path derivation
3. Create plan-diff prompt (2b.5)
4. Refine extraction prompt (2b.1)

## Notes

- Processing order is: extraction → handoff → progress → status (status last so it can link to new handoff)
- The prompts follow the same style as session-extraction.md
- Plan diff prompt still needed for detecting semantic changes in plan files
