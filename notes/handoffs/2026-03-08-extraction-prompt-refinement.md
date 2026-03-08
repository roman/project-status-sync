# Handoff: Extraction Prompt Refinement

**Date**: 2026-03-08
**Phase**: 2b.1

## What Was Done

- Fixed contradiction: intro said "Call record-event" but output format showed
  `[tag] text` lines. Aligned to `[tag] text` as the prompt's output format
  (Phase 2c calling code will parse these and write to EVENTS.jsonl).
- Added "Transcript Format" section: explains USER:/ASSISTANT:/THINKING: labels
  from the pre-filter output. Notes that THINKING blocks are high-signal content
  containing reasoning behind decisions.
- Strengthened signal-to-noise: more specific skip criteria (debugging noise,
  false starts, routine code changes, tool output), quantity guidance (3-7 typical,
  15+ is noise), guard against inventing events to meet quotas.
- Improved tag definitions: `decision` now requires naming what was chosen and
  rejected. `resolved` requires stating what was resolved and how. `initiative`
  explicitly says "most sessions should have zero."
- Added self-containment guidance for observations.
- Empty result is now valid (no fallback meta-event polluting EVENTS.jsonl).

## What's Next

- Phase 2b is now complete (all 4 prompts done).
- Phase 2c (Integration) is the next workstream: wire aggregation job to invoke
  extraction prompt via `claude -p` and parse `[tag] text` output.
- Design doc (`docs/design.md`) Prompt Inventory table still references
  `record-event` calls as the extraction output format — should be updated
  when Phase 2c implements the actual parsing strategy.

## Notes

- The `[tag] text` format was chosen over direct `record-event` CLI calls
  because it's simpler, more testable, and doesn't require bash tool access
  in the `claude -p` subprocess. Phase 2c will parse stdout lines.
- Code-critic flagged the design doc inconsistency — deferred to Phase 2c
  when the actual integration approach is decided.
