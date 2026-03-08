# Handoff: Mandatory Prompt Fields (Proposal Option B)

**Date**: 2026-03-08
**Session**: 8374e96c

## What Was Done

Implemented approved proposal (Option B): removed `Maybe` from `pcHandoffPrompt` and
`pcProgressPrompt` in `ProcessConfig`. CLI flags `--handoff-prompt` and `--progress-prompt`
are now required — omitting them produces a usage error instead of silent no-op.

Changes:
- `ProcessConfig`: `!(Maybe FilePath)` → `!FilePath` for both prompt fields
- `AggregateCmd`: same type change in positional constructor
- `aggregateParser`: `optional (option str ...)` → `option str ...` (required)
- `generateHandoff`/`generateProgressEntry`: removed `case Nothing/Just` branches,
  replaced with simple `if null events` guard

72 tests pass. No test changes needed (tests don't reference ProcessConfig directly).

## What's Next

- Extract `AggregateConfig` record from `AggregateCmd` (now unblocked)
- Phase 3.3: wire synthesis prompt (add `pcSynthesisPrompt :: !FilePath`)
- Update `docs/design.md` to reflect stdout-parsing approach
