# Handoff: Wire Synthesis Prompt into processSession

**Date**: 2026-03-08
**Session**: 866b9545

## What Was Done

Wired the synthesis prompt (Phase 3.3) into the processSession pipeline. After extraction,
handoff generation, and progress entry, the pipeline now invokes the synthesis prompt with
all accumulated EVENTS.jsonl content plus handoff file listing, then writes STATUS.md to
the project directory.

Changes:
- `ProcessConfig`: added `pcSynthesisPrompt :: !FilePath`
- `AggregateConfig`: added `acSynthesisPrompt :: !FilePath`
- CLI: added `--synthesis-prompt` required flag to `ccs aggregate`
- `generateStatus` function: reads EVENTS.jsonl, lists handoff files, runs synthesis
  prompt, overwrites STATUS.md
- Added input size logging for diagnosability (code-critic recommendation)

72 tests pass. No test changes needed.

## What's Next

- Phase 3.4: Quality validation (generate outputs for this project, read STATUS.md cold)
- Phase 2c.2: End-to-end testing (needs real sessions outside sandbox)
- Review gate: after 3.4, assess whether unbounded EVENTS.jsonl input needs truncation
