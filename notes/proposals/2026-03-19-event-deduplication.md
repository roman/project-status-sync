# Event Deduplication Strategy

**Date**: 2026-03-19
**Status**: REJECTED
**Superseded by**: `2026-03-19-incremental-extraction.md`
**Rejection reason**: All three options (hash dedup, session replace, read-time dedup) either
break append-only semantics or have key-design problems. A watermark-based incremental
approach avoids the dedup problem entirely by not re-extracting already-processed messages.
**Affects**: `src/CCS/Event.hs`, `src/CCS/Process.hs`, `EVENTS.jsonl` semantics

## Problem Statement

When the same session is processed more than once (e.g., a continued session produces a new
signal, or a session is reprocessed after a failure), `appendJsonLine` appends events
unconditionally to EVENTS.jsonl. This produces near-identical events with slightly different
wording. In the cell-controller outputs, session `ff9aabbd` was processed on both 2026-03-18
and 2026-03-19, producing duplicate decision/context events (lines 1-5 repeat as lines 13-19
with minor wording changes).

Impact: inflated EVENTS.jsonl, duplicate information fed to synthesis prompt (wastes tokens,
may confuse synthesis), and duplicate handoffs covering the same ground.

## The Real Question

Should deduplication happen at write time (prevent duplicates from entering EVENTS.jsonl),
at read time (filter duplicates when consuming events), or at the session level (replace
all events for a re-processed session)?

## Decision Matrix

| Criterion                        | A: Hash-based write dedup | B: Session-keyed replace | C: Read-time dedup |
|----------------------------------|:---:|:---:|:---:|
| Implementation complexity        | :yellow_circle: read file + hash check per event | :yellow_circle: read-filter-rewrite per session | :green_circle: ~5 lines in parseEventsJsonl |
| EVENTS.jsonl remains append-only | :red_circle: must read before writing to check hashes | :red_circle: must rewrite file to remove old session events | :green_circle: file untouched, dedup only in memory |
| Handles wording drift            | :red_circle: "removed X entirely" vs "removed X" hash differently, both kept | :green_circle: replaces all prior events for session, wording irrelevant | :yellow_circle: depends on dedup key — (session, tag) too coarse, (session, tag, text) defeated by drift |
| Handles legitimate re-extraction | :red_circle: improved wording silently dropped if hash matches prior version | :green_circle: latest extraction always wins, old one discarded | :yellow_circle: latest wins per key, but key design determines what counts as "same" |
| Storage efficiency               | :green_circle: duplicates never written to disk | :green_circle: old events removed, only latest kept | :red_circle: duplicates accumulate on disk, only filtered in memory |
| Auditability (full history)      | :red_circle: prior extractions silently skipped, no record of what was dropped | :red_circle: prior extractions overwritten, no diff visible | :green_circle: all extractions preserved in file, full history of how events evolved |

### Option A: Hash-based write dedup

Hash each event by `(session, tag, normalized text)` before appending. Skip if the hash
already exists in the file.

- Pro: prevents duplicates at the source
- Con: must read the entire file on every append to check hashes (O(n) per event)
- Con: wording drift defeats exact hashing — "removed MigrationOriginalMaxReplicas from
  Revision spec entirely" vs "removed MigrationOriginalMaxReplicas from Revision spec"
  would be treated as different events
- Con: breaks the append-only invariant (must read before writing)
- Con: if re-extraction produces genuinely better wording, the improved version is silently
  dropped

### Option B: Session-keyed replacement

When processing a session, delete all existing events for that session ID from EVENTS.jsonl
before appending the new extraction. Effectively "the latest extraction wins."

- Pro: cleanly handles re-processing — latest extraction always wins
- Pro: handles wording drift (replaces rather than deduplicates)
- Pro: storage-efficient
- Con: requires rewriting EVENTS.jsonl (read all lines, filter, rewrite + append)
- Con: loses history of prior extractions (acceptable — the session transcript is the
  source of truth, not prior extractions)
- Con: breaks append-only semantics (must rewrite file)

### Option C: Read-time dedup

Leave EVENTS.jsonl as a pure append-only log. When reading events for synthesis, deduplicate
by `(session, tag)` keeping the latest entry (last occurrence in file wins).

- Pro: simplest implementation — add dedup to `parseEventsJsonl`
- Pro: EVENTS.jsonl stays append-only (no write-path changes)
- Pro: full audit trail preserved — can see how extractions evolved
- Con: EVENTS.jsonl grows unbounded with duplicates (mitigated by Phase 5 archival)
- Con: dedup by `(session, tag)` may be too aggressive if a session legitimately has
  multiple events with the same tag (e.g., two different decisions)
- Con: wording drift means "latest wins" may not always be "best" — but re-extraction
  on a longer transcript should generally be more complete

## Recommendation: Option B (Session-keyed replacement)

Option C is simplest but the `(session, tag)` dedup key is problematic — sessions
routinely have multiple `decision` or `context` events, and collapsing them to one per tag
would lose information. A finer-grained key like `(session, tag, text)` brings back the
wording-drift problem from Option A.

Option B avoids the key-design problem entirely: when a session is re-processed, all its
prior events are replaced wholesale. The latest extraction from the full transcript is
always the most complete. The file rewrite cost is acceptable — EVENTS.jsonl is small
(the cell-controller file is 21 lines after 3 sessions) and Phase 6.5 caps signals at 20
per run.

### Concrete Changes

1. New function `replaceSessionEvents :: FilePath -> SessionId -> [EventLogEntry] -> RIO env ()`
   - Read all lines from EVENTS.jsonl
   - Filter out lines where `.session` matches the given session ID
   - Append new events
   - Write atomically (write to temp file, rename)
2. Replace `mapM_ (appendJsonLine eventsFile) entries` call in `processSession` with
   `replaceSessionEvents eventsFile sessionId entries`
3. Add test: process same session twice, verify EVENTS.jsonl contains only the second
   extraction's events for that session

### Trade-offs

- Loses the append-only property of EVENTS.jsonl (requires atomic rewrite)
- Prior extractions are not preserved (acceptable — transcript is the source of truth)
- Slightly more I/O per session (read + rewrite vs. pure append)

### Risk

Low. EVENTS.jsonl is small, the rewrite is atomic (temp file + rename), and the semantic
improvement (no duplicates) outweighs the minor I/O cost.

## Evolution Path

- **Trigger**: EVENTS.jsonl grows beyond 10K lines or Phase 5 (Archival) is implemented
- **Question**: Should `replaceSessionEvents` operate on a bounded recent window rather
  than the full file?
- **Reference**: Option C (read-time dedup) may become preferable if the file is large
  enough that rewriting becomes expensive

## Review Notes

*(To be filled after human review)*
