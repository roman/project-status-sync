# Handoff: Extract AggregateConfig Record

**Date**: 2026-03-08
**Session**: 9c7e385d

## What Was Done

Extracted `AggregateConfig` named record from the `AggregateCmd` constructor in `app/Main.hs`.
Previously, `AggregateCmd` had 6 positional `!FilePath`/`!Int` fields which were fragile and
hard to read at the pattern match site. Now `AggregateCmd` wraps a single `!AggregateConfig`
record with `ac`-prefixed fields (matching `pc` prefix convention from `ProcessConfig`).

Changes limited to `app/Main.hs`:
- New `AggregateConfig` type with 6 strict fields
- `AggregateCmd` constructor takes `!AggregateConfig`
- Parser uses `fmap AggregateCmd $ AggregateConfig <$> ...`
- Pattern match uses `RecordWildCards` for field destructuring

72 tests pass. No library code changes.

## What's Next

- Phase 3.3: Wire synthesis prompt into processSession (add `pcSynthesisPrompt :: !FilePath`)
- Phase 2c.2: End-to-end testing (needs real sessions outside sandbox)
