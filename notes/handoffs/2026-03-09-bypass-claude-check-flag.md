# Handoff: Add --bypass-claude-check flag

**Date**: 2026-03-09
**Session**: 461e49e9
**Role**: Implementer

## What Was Done

Added `--bypass-claude-check` CLI flag to `ccs aggregate` that strips the `CLAUDECODE`
env var from child process environment before spawning `claude -p`.

When running inside a ralph loop, the parent Claude session sets `CLAUDECODE` to guard
against recursive invocations. This leaked into `claude -p` subprocesses spawned by
`runLLMPrompt`, causing them to refuse to start. The flag makes env stripping opt-in.

Changes:
- `CCS.Process`: added `pcBypassClaudeCheck :: !Bool` to `ProcessConfig`
- `runLLMPrompt`: conditionally reads parent env and filters out `CLAUDECODE`
- `app/Main.hs`: added `acBypassClaudeCheck` to `AggregateConfig`, `--bypass-claude-check`
  switch to aggregate parser, wired into `ProcessConfig`

79 tests pass.

## Spec Compliance

WORKPLAN item: "`CLAUDECODE` env var prevents `claude -p` subprocess — add explicit CLI flag (e.g. `--bypass-claude-check`) that strips `CLAUDECODE` from child env"

- Explicit CLI flag: met — `--bypass-claude-check` switch on `ccs aggregate`
- Strips CLAUDECODE from child env: met — filters via `getEnvironment` + `setEnv`
- Opt-in behavior: met — default is `False`, only activates when flag is passed

## What's Next

- Phase 3.4: Quality validation (human-verified, requires real pipeline run)
- Phase 4: Retrieval (deferred)
