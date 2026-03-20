# Incremental Extraction via Extraction Cursors

**Date**: 2026-03-19
**Status**: APPROVED
**Affects**: `src/CCS/Filter.hs`, `src/CCS/Process.hs`, extraction prompt

## Problem Statement

When the same session is processed more than once (e.g., a continued session produces a new
signal, or a session is reprocessed after a failure), `appendJsonLine` appends events
unconditionally to EVENTS.jsonl. This produces near-identical events with slightly different
wording because the LLM re-extracts from the full transcript, including already-processed
messages.

Impact: inflated EVENTS.jsonl, duplicate information fed to synthesis prompt (wastes tokens,
may confuse synthesis), and duplicate handoffs covering the same ground.

Observed in production: session `ff9aabbd` in cell-controller was processed on both
2026-03-18 and 2026-03-19, producing duplicate decision/context events (EVENTS.jsonl
lines 1-5 repeat as lines 13-19 with minor wording changes).

## The Real Question

How do we avoid re-extracting events from messages we've already processed, while preserving
EVENTS.jsonl's append-only semantics?

## Key Observation: Session Messages Have Unique UUIDs

Each message in a Claude Code session JSONL has a `uuid` field (UUIDv4). While not
monotonically increasing, UUIDs are unique within a session. Messages appear in the JSONL
file in chronological order, so "everything after UUID X" is a valid cursor — implemented
as a linear scan-until-found.

The design doc already specifies `MessageUuid`, `SessionCheckpoint`, and `SessionCursor`
types for this purpose (design.md lines 617-630).

**Alternative**: since session JSONL files are append-only (Claude Code only appends via
`--continue`), a line-count cursor would also be stable and avoid UUID parsing entirely.
See Option C below.

## Decision Matrix

| Criterion                        | A: Session-keyed replace | B: UUID-based cursor | C: Line-count cursor |
|----------------------------------|:---:|:---:|:---:|
| EVENTS.jsonl stays append-only   | :red_circle: requires file rewrite | :green_circle: pure append | :green_circle: pure append |
| Avoids duplicate events          | :green_circle: replaces all prior | :green_circle: only extracts new messages | :green_circle: only extracts new messages |
| LLM token efficiency             | :red_circle: re-extracts entire transcript | :green_circle: only new message slice | :green_circle: only new message slice |
| Implementation complexity        | :yellow_circle: read-filter-rewrite | :yellow_circle: UUID parsing + scan-until-found | :green_circle: line count + `drop` |
| Robustness to file changes       | :green_circle: no cursor to invalidate | :yellow_circle: UUID not found → full fallback | :yellow_circle: line count invalid → full fallback |
| Alignment with design doc        | :red_circle: not in design doc | :green_circle: uses `SessionCursor` / `MessageUuid` | :yellow_circle: simpler than design doc types |
| Audit trail preserved            | :red_circle: prior extractions deleted | :green_circle: all events preserved | :green_circle: all events preserved |

### Option A: Session-keyed replacement (rejected)

When processing a session, delete all existing events for that session ID from EVENTS.jsonl
before appending new ones. Breaks append-only semantics and loses audit trail. See
`2026-03-19-event-deduplication.md` for full analysis.

### Option B: UUID-based extraction cursor

Track the UUID of the last message processed per session. On re-processing, scan the
transcript JSONL until the cursor UUID is found, then only feed messages after that point
to the LLM.

- Pro: aligns with design doc's `SessionCheckpoint` / `SessionCursor` types
- Pro: cursor survives if lines are inserted mid-file (unlikely but possible)
- Con: requires parsing `uuid` from session JSONL (currently ignored by `SessionEntry`)
- Con: linear scan to find cursor UUID

### Option C: Line-count extraction cursor

Track the number of JSONL lines processed per session. On re-processing, skip that many
lines and only feed the remainder to the LLM.

- Pro: simplest implementation — no UUID parsing, just `drop n`
- Pro: mirrors the existing synthesis `Watermark` pattern (line-count based)
- Con: fragile if Claude Code ever rewrites session files (no evidence this happens)
- Con: does not use the design doc's `MessageUuid` types (but those can be adopted later)

## Recommendation: Option C (Line-count cursor), with Option B as evolution path

Line-count cursoring is the simplest approach that solves the problem. Session JSONL files
are append-only in practice (Claude Code only adds via `--continue`), so line count is a
stable cursor. This mirrors the existing synthesis `Watermark` pattern, reducing cognitive
load.

If we later discover that session files can be rewritten or that line-count cursors are
unreliable, Option B (UUID-based) is a clean upgrade path — the cursor storage format
supports it and the design doc types are ready.

### Concrete Changes

1. **`ExtractionCursor` newtype** — in `src/CCS/Process.hs` (or a new `src/CCS/Cursor.hs`)
   ```haskell
   newtype ExtractionCursor = ExtractionCursor { cursorLineCount :: Int }
     deriving stock (Eq, Show)
   ```
   - Prevents mixing up raw `Int` values with cursor positions (same motivation as
     the existing `Watermark` newtype for synthesis)
   - Smart constructor validates non-negative values at parse boundary

2. **Extraction cursor storage** — new file `{projectDir}/.extraction-cursors.json`
   - Format: `Map SessionId ExtractionCursor` (session ID → line count last processed)
   - Read/write functions alongside the newtype
   - Separate from the synthesis `.last-synthesized` cursor (different concern)

3. **Transcript slicing** — decompose into pure, testable functions in `src/CCS/Filter.hs`
   ```haskell
   -- Drop already-processed lines, filter and format the rest
   filterTranscriptFrom :: ExtractionCursor -> LBS.ByteString -> (Text, ExtractionCursor)
   -- Returns (filtered transcript, updated cursor for storage)
   ```
   - `filterTranscriptFile` becomes a convenience wrapper calling this
   - Each function is independently testable
   - `ExtractionCursor` in the signature makes it impossible to accidentally pass
     a synthesis watermark position or an arbitrary integer

4. **Wire into `processSession`** (`src/CCS/Process.hs`)
   - Before extraction: read `.extraction-cursors.json`, look up session ID
   - Pass `ExtractionCursor` to `filterTranscriptFrom`
   - After extraction: update cursor file with returned `ExtractionCursor`
   - On cursor miss (session not in map): use `ExtractionCursor 0` (full transcript)

4. **No changes to `EventLogEntry`** — the cursor is metadata about the extraction run,
   not about individual events. It lives in the cursor file, not the event schema.

### Trade-offs

- Adds a cursor file per project directory (`.extraction-cursors.json`)
- Line-count cursor assumes session JSONL is append-only (true in practice)
- Does not use design doc's `MessageUuid` types yet (deferred to evolution path)

### Risk

Low. The core change is `drop n` on JSONL lines before filtering. EVENTS.jsonl write path
is unchanged (`appendJsonLine`). Worst case on cursor miss: falls back to full transcript
processing (current behavior, produces duplicates as today — no regression).

## Evolution Path

- **Trigger**: Evidence that session JSONL files can be rewritten mid-file, invalidating
  line-count cursors
- **Question**: Should we upgrade to UUID-based cursoring (Option B)?
- **Reference**: Design doc `SessionCursor` / `MessageUuid` types are ready for this.
  The cursor file format can be extended from `Map SessionId ExtractionCursor` to
  `Map SessionId SessionCheckpoint` without breaking existing cursor files (the newtype
  boundary makes this a localized change).

## Review Notes

- Naming: uses "extraction cursor" to avoid collision with the existing synthesis
  `Watermark` type in `Process.hs`
- Cursor lives in a separate file, not on `EventLogEntry` — avoids schema migration
  and `Maybe` field pollution
- "Existing events as prompt context" removed — transcript slicing alone prevents
  re-extraction; context injection is speculative and can be added later if needed
- Decomposed transcript slicing into pure functions for testability
