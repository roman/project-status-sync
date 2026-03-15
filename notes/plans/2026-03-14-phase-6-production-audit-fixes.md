# Phase 6: Production Audit Fixes

**Date**: 2026-03-14
**Phase**: 6 (6.1–6.5)
**Status**: PLAN — approved, not yet implemented

## Main Directive

The project-status-sync service wastes ~90% of its LLM token budget on redundant synthesis
calls, duplicate handoffs, and processing non-git sessions. Fix this so the service runs
within its systemd timeout and produces non-redundant output.

**We will know this is working when**: a batch of 20+ signals processes in under 5 minutes,
produces at most 1 STATUS.md per project, zero handoffs for non-git sessions, and no
near-duplicate handoffs for same-topic sessions.

## Dependency Graph

```
6.5 (timeout + max-signals) ── independent, unblocks backlog clearing
6.1 (skip non-git)          ── independent, immediate token savings
6.3 (handoff dedup)         ── independent
6.2 (batch synthesis)       ── depends on 6.1 (shares Maybe Project return type)
6.4 (incremental synthesis) ── depends on 6.2
```

6.5, 6.1, and 6.3 can be done in any order or parallel. 6.2 after 6.1. 6.4 last.

---

## 6.1: Skip Non-Git Projects

### Problem

Sessions started from `~/` (not a git repo) fall back to `deriveName` on the raw path,
producing project name "roman." These are grab-bag sessions that pollute EVENTS.jsonl.

### Design

**Change `identifyProject` return type** from `m Project` to `m (Maybe Project)`.

In `CCS.Project`:
- When `git rev-parse --show-toplevel` fails AND no git remote is found, return `Nothing`
- Delete `directoryFallback` (or make it unexported dead code)
- All callers must handle the `Nothing` case

**Change `processSession`** to pattern-match:
```haskell
mProject <- identifyProject (asProjectPath signal)
case mProject of
  Nothing -> logInfo $ "Skipping non-git session " <> display sid
  Just project -> do
    -- existing processing from line 188 onward
```

Signal consumption happens in `runAggregation` regardless — no change needed there.

### Files

- `src/CCS/Project.hs` — `identifyProject` return type, delete `directoryFallback`
- `src/CCS/Process.hs` — `processSession` handles `Nothing`
- `test/` — update tests that call `identifyProject`

### Gates

- [ ] `identifyProject "/home/roman"` returns `Nothing`
- [ ] `identifyProject "/home/roman/Projects/self/project-status-sync"` returns `Just`
- [ ] Signal for non-git session is consumed (deleted) without LLM calls
- [ ] `cabal test` passes

---

## 6.2: Batch-Aware Synthesis

### Problem

`processSession` calls `generateStatus` after every session. With 53 signals, synthesis
runs 53× reading 64K chars each time. Only the last output matters.

### Design

**Split `processSession`**: extraction + handoff + progress stay per-session. Synthesis
moves to the caller.

Type changes:

| What | Before | After |
|------|--------|-------|
| `processSession` | `RIO env ()` | `RIO env (Maybe Project)` |
| `runAggregation` callback | `Signal -> RIO env ()` | `Signal -> RIO env (Maybe Project)` |
| `AggregateResult` | `AggregatedSessions !Int` | `AggregatedSessions !Int ![Project]` |

**`processSession`** returns `Just project` on success, `Nothing` when skipped (non-git,
empty transcript, extraction failure). Removes the `generateStatus` call entirely.

**`runAggregation`** collects results:
```haskell
results <- forM signals $ \signal -> do
  result <- processOne signal
  consumeSignal signal
  pure result
let touchedProjects = nubBy ((==) `on` projectKey) (catMaybes results)
pure (AggregatedSessions (length signals) touchedProjects)
```

**`generateStatus`** becomes standalone — drops the `AvailabilitySignal` parameter:
```haskell
generateStatusForProject :: HasLogFunc env
  => ProcessConfig -> Project -> RIO env ()
```

It derives `projectDir` from `pcOutputDir + deriveOutputSubpath`, finds EVENTS.jsonl, runs
synthesis. The current `generateStatus` already does this; just remove the signal dependency.

**Caller in `app/Main.hs`**:
```haskell
case result of
  AggregatedSessions n projects -> do
    logInfo $ "Processed " <> display n <> " session(s)"
    forM_ projects $ generateStatusForProject config
```

### Files

- `src/CCS/Process.hs` — split `processSession`, extract `generateStatusForProject`
- `src/CCS/Aggregate.hs` — `runAggregation` callback type, `AggregateResult` change
- `app/Main.hs` — call synthesis after aggregation
- `test/` — update tests

### Gates

- [ ] `processSession` does not call `generateStatus`
- [ ] With 5 signals for same project, synthesis runs exactly once
- [ ] With signals for 2 different projects, synthesis runs exactly twice
- [ ] `cabal test` passes

---

## 6.3: Handoff Dedup via Prior Context

### Problem

The handoff prompt has zero awareness of previous handoffs. 16 sessions on the same topic
produce 16 near-identical handoff documents.

### Design

**In `generateHandoff`**, read the handoff directory listing (same pattern already used in
`generateStatus` lines 316-328) and prepend to the prompt input:

```haskell
handoffExists <- doesDirectoryExist handoffDir
handoffFiles <- if handoffExists
  then sort <$> listDirectory handoffDir
  else pure []

let
  priorContext = case handoffFiles of
    [] -> ""
    fs -> "Previous handoffs in this project:\n"
          <> T.unlines (map (\f -> "- " <> T.pack f) fs)
          <> "\n"
  metadata = "Project session metadata:\n"
          <> "Date: " <> T.pack (show today) <> "\n"
          <> "Session: " <> sid <> "\n\n"
          <> priorContext
```

**In `prompts/handoff-generation.md`**, add to Input section:
```
3. (Optional) List of previous handoff filenames for this project
```

Add to Quality Criteria:
```
- Avoid redundancy: if previous handoffs already cover the same topic, focus only on
  what THIS session added that is genuinely new. If the session's events are entirely
  covered by existing handoffs, output only the TOPIC line with no markdown body.
```

Token cost: ~40 tokens for 20 filenames. Negligible.

### Files

- `src/CCS/Process.hs` — `generateHandoff` reads handoff dir
- `prompts/handoff-generation.md` — add prior context instructions

### Gates

- [ ] `generateHandoff` includes prior filenames in prompt input
- [ ] Prompt instructs LLM to suppress redundant content
- [ ] `cabal test` passes

### Evolution path

If filenames prove insufficient, next step is feeding last 3 handoff file contents (capped
at 500 tokens). That builds on this foundation without redesign.

---

## 6.4: Incremental Synthesis with Watermark Cursor

**Depends on**: 6.2 (batch-aware synthesis must land first)

### Problem

Synthesis reads the entire EVENTS.jsonl on every run. 222 events = 64K chars input. Grows
linearly with project age. Additionally, raw JSONL wastes tokens on redundant fields
(`project`, `project_key`, `source`) that synthesis doesn't need.

### Design

#### 6.4a: Compact event format

New pure function:
```haskell
formatEventsCompact :: [EventLogEntry] -> Text
```

Groups entries by `(eleDate, eleSessionId)`, sorts chronologically, renders:

```
## 2026-03-11 [04fe7783]

- [resolved] project-status-sync module had a stale assertion
- [decision] use file-embed for prompt embedding
- [next] wire orgMappings to CLI flags

## 2026-03-11 [a1b2c3d4]

- [context] 222 events accumulated, synthesis taking 11 min
```

Drops `project`, `project_key`, `source`. Truncates session ID to 8 chars. ~60-70% token
reduction vs raw JSONL.

#### 6.4b: Watermark cursor

After synthesis, write `{projectDir}/.last-synthesized` containing one integer: the line
count of EVENTS.jsonl at time of synthesis.

```
222
```

Why line count:
- EVENTS.jsonl is append-only. Line N today is line N tomorrow.
- `drop cursor (lines content)` gives exactly the new events. Zero parsing for the split.
- Missing/corrupt file → treat as 0 (full resync)
- Cursor > file length → treat as 0 (file was rebuilt)

#### 6.4c: Incremental generateStatus flow

```
1. Read .last-synthesized → cursor (Int), default 0
2. Read EVENTS.jsonl, parse all EventLogEntry values
3. If cursor >= length entries AND cursor > 0 → no new events, skip
4. newEntries = drop cursor entries
5. If cursor == 0 (full resync):
     - Format ALL entries via formatEventsCompact
     - Feed to synthesis prompt (no previous STATUS.md section)
6. If cursor > 0 (incremental):
     - Read existing STATUS.md
     - Format only newEntries via formatEventsCompact
     - Feed previous STATUS.md + new events to prompt
7. Write output STATUS.md
8. Write (length entries) to .last-synthesized
```

#### 6.4d: Updated synthesis prompt

Single prompt with optional "Previous STATUS.md" section. Input format:

```
Project: roman

Recent handoff files:
- handoffs/2026-03-11-04fe7783-topic.md

## Previous STATUS.md

(contents of existing STATUS.md, or "No previous status — generate from full history.")

## Events

## 2026-03-11 [04fe7783]

- [resolved] fixed stale assertion
- [decision] changed outputDir
```

Prompt instruction addition: "If a previous STATUS.md is provided, update it with the new
events. Preserve information from the previous status that is still relevant. If no previous
status is provided, generate from scratch using all events."

Remove the "Session:" line from input — meaningless in batch mode. Events carry session IDs.

#### 6.4e: `--full-resync` CLI flag

```
--full-resync    Force full STATUS.md regeneration (ignore .last-synthesized cursor)
```

Thread a `Bool` through `ProcessConfig` (or a separate config). When true, treat cursor as 0.
Still writes the new cursor after synthesis so subsequent runs are incremental.

### Files

- `src/CCS/Process.hs` — `formatEventsCompact`, cursor logic, updated `generateStatus`
- `prompts/status-synthesis.md` — updated for compact format + incremental mode
- `app/Main.hs` — `--full-resync` flag
- `test/` — tests for `formatEventsCompact`, cursor edge cases

### Gates

- [ ] `formatEventsCompact` produces correct grouped output (unit test)
- [ ] Cursor file written after synthesis with correct line count
- [ ] Incremental mode: only new events fed to prompt (verify via log output)
- [ ] Full resync mode: all events fed, no previous STATUS.md
- [ ] Missing cursor file triggers full resync
- [ ] `--full-resync` flag works
- [ ] `cabal test` passes

---

## 6.5: Service Runtime Hardening

### Problem

systemd `Type=oneshot` with no explicit `TimeoutStartSec`. Service was SIGTERMed after 11
min processing 53 signals. 257 signals still queued.

### Design

**A. Set `TimeoutStartSec = "30min"`** in the Nix module.

Normal operation (1-5 signals): 30 seconds to 2.5 minutes. Well within timeout.
Backlog (50 signals): ~25 minutes. Within 30-minute timeout.

One line in `nix/modules/home-manager/project-status-sync/default.nix`:
```nix
Service = {
  Type = "oneshot";
  ExecStart = toString aggregateScript;
  TimeoutStartSec = "30min";
};
```

**B. `--max-signals N` flag** (default 20) on `ccs aggregate`.

`runAggregation` takes at most N signals: `take maxSignals signals`. Rest processed next
timer fire. At ~30 seconds per signal, 20 signals ≈ 10 minutes worst case.

Add `maxSignals` option to Nix module, wire to CLI flag.

### Files

- `nix/modules/home-manager/project-status-sync/default.nix` — `TimeoutStartSec`, `maxSignals` option
- `src/CCS/Aggregate.hs` — `runAggregation` takes max-signals parameter
- `app/Main.hs` — `--max-signals` CLI flag

### Gates

- [ ] Service has `TimeoutStartSec = "30min"` in generated unit file
- [ ] `--max-signals 5` processes exactly 5 signals, leaves rest
- [ ] `cabal test` passes

---

## Cleanup: Clear Signal Backlog

After 6.1 and 6.5 land, clear the existing 257-signal backlog:

```bash
# Option A: let the service chew through it (20 signals per 5 min = ~65 min)
systemctl --user restart project-status-sync.timer

# Option B: manually discard non-git signals (faster)
# Inspect signals, delete ones with cwd=/home/roman
for f in ~/.local/state/ccs/signals/*.available; do
  cwd=$(jq -r .cwd "$f")
  git -C "$cwd" rev-parse --show-toplevel 2>/dev/null || rm "$f"
done
```

---

## Session Guidance

Each item (6.1–6.5) is a single focused session. Implementation order:

1. **Session 1**: 6.5 (timeout + max-signals) — smallest, unblocks backlog clearing
2. **Session 2**: 6.1 (skip non-git) — immediate token savings, changes `identifyProject` return type
3. **Session 3**: 6.3 (handoff dedup) — independent, small change
4. **Session 4**: 6.2 (batch synthesis) — builds on 6.1's `Maybe Project`, restructures flow
5. **Session 5**: 6.4 (incremental synthesis) — builds on 6.2, most involved change

Each session should: implement → `cabal test` → code-critic review → update WORKPLAN → commit.
