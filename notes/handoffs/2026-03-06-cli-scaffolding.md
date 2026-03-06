# Phase 2a.2: CLI Scaffolding

**Date**: 2026-03-06
**Status**: Complete

## What was done

Replaced the stub `app/Main.hs` with optparse-applicative CLI scaffolding:

- `ccs filter FILE` — reads JSONL transcript, outputs filtered plain text to stdout
- `ccs aggregate` — skeleton that logs "not yet implemented"
- `ccs --version` / `ccs -V` — prints version from Paths_ccs

## Design decisions

- Filter output goes to stdout (for piping), RIO logging goes to stderr
- Used `Data.Text.IO.hPutStr` for stdout output instead of RIO's
  `hPutBuilder`/`getUtf8Builder`/`display` chain (simpler, more obvious)
- Added `text` to executable build-depends for `Data.Text.IO`
- No error handling on file read — raw IOException for now, acceptable
  at scaffolding phase

## Next steps

- 2a.3: record-event tool (`--tag`, `--text`, `--source` → append JSONL)
- 2a.4: Aggregation job skeleton (signal watching, quiet period, locking)
