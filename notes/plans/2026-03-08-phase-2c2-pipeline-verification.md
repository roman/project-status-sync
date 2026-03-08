# Test Plan: Phase 2c.2 — End-to-End Pipeline Verification

**WORKPLAN gate**: "End-to-end: session ends → EVENTS.jsonl updated"
**Drives**: LLM agent reads this, walks human through each step interactively.

---

## Agent Protocol

1. Work through steps in order. Do not skip.
2. Before each step, tell the human what to do and why.
3. After each step, ask for output or observation.
4. Record PASS/FAIL with evidence. FAIL → diagnose before continuing.
5. Steps marked `[BLOCKS: ...]` prevent downstream steps on failure.
6. Maintain a results table. Present it at the end.

---

## Prerequisites

Verify with the human before starting:

- [ ] `nix develop --impure` shell available
- [ ] `cabal build` succeeds
- [ ] `claude` CLI on PATH and authenticated
- [ ] Human has access to a real transcript JSONL
  (`~/.claude/projects/<hash>/<session>.jsonl`)

---

## Step 1 — Hook Script Smoke Test

**Goal**: Signal file creation from synthetic input.

```bash
export CCS_SIGNAL_DIR=$(mktemp -d)
echo '{"session_id":"test-1234","transcript_path":"/tmp/fake.jsonl","cwd":"/tmp"}' \
  | bash scripts/session-end-hook.sh
ls -la "$CCS_SIGNAL_DIR"
cat "$CCS_SIGNAL_DIR/test-1234.available"
```

**PASS**: `test-1234.available` exists, contains `{"transcript_path":"/tmp/fake.jsonl","cwd":"/tmp"}`.
**BLOCKS**: All subsequent steps.

---

## Step 2 — Filter on Real Transcript

**Goal**: `ccs filter` produces clean text from real JSONL.

Ask human to pick a transcript, then:

```bash
cabal run ccs -- filter <transcript.jsonl> | head -50
```

**PASS**: Plain text with `USER:` / `ASSISTANT:` / `THINKING:` labels, no raw JSON.
**BLOCKS**: Step 4.

---

## Step 3 — Signal Discovery

**Goal**: Aggregation finds signal files.

```bash
SIGNAL_DIR=$(mktemp -d)
echo '{"transcript_path":"/tmp/fake.jsonl","cwd":"/tmp"}' \
  > "$SIGNAL_DIR/test-signal.available"

cabal run ccs -- aggregate \
  --signal-dir "$SIGNAL_DIR" \
  --quiet-minutes 0 \
  --output-dir /tmp/ccs-test-output \
  --prompt-file prompts/session-extraction.md \
  --handoff-prompt prompts/handoff-generation.md \
  --progress-prompt prompts/progress-entry.md \
  --synthesis-prompt prompts/status-synthesis.md
```

**PASS**: Log says "Processing 1 signal(s)". Will fail on filter (fake path) — that's fine.
**BLOCKS**: Step 4.

---

## Step 4 — Full Pipeline with Real Transcript

**Goal**: Signal → filter → extraction → handoff → progress → STATUS.md.

Makes 4 LLM API calls. Ask human to confirm they're OK with the cost.

```bash
SIGNAL_DIR=$(mktemp -d)
OUTPUT_DIR=$(mktemp -d)
TRANSCRIPT="<real-transcript.jsonl>"
CWD="<cwd-of-that-session>"

echo "{\"transcript_path\":\"$TRANSCRIPT\",\"cwd\":\"$CWD\"}" \
  > "$SIGNAL_DIR/e2e-test.available"

cabal run ccs -- aggregate \
  --signal-dir "$SIGNAL_DIR" \
  --quiet-minutes 0 \
  --output-dir "$OUTPUT_DIR" \
  --prompt-file prompts/session-extraction.md \
  --handoff-prompt prompts/handoff-generation.md \
  --progress-prompt prompts/progress-entry.md \
  --synthesis-prompt prompts/status-synthesis.md
```

Then inspect:

```bash
echo "=== EVENTS ===" && cat "$OUTPUT_DIR"/*/EVENTS.jsonl
echo "=== Handoff ===" && cat "$OUTPUT_DIR"/*/handoffs/*.md
echo "=== Progress ===" && cat "$OUTPUT_DIR"/*/progress.log
echo "=== STATUS ===" && cat "$OUTPUT_DIR"/*/STATUS.md
```

**Evaluate each output**:

| Output | PASS criteria |
|--------|--------------|
| EVENTS.jsonl | Valid JSONL, each line has `date`, `session`, `project`, `tag`, `text` |
| EVENTS.jsonl | Events are meaningful (not noise) |
| handoffs/*.md | File exists with topic-based filename, 50-150 words |
| progress.log | Single line, format `YYYY-MM-DD HH:MM [prefix] — summary` |
| STATUS.md | Structured document, references handoff files |

**PASS**: All 4 outputs exist and are reasonable.
**BLOCKS**: Step 5.

---

## Step 5 — Signal Consumption

**Goal**: Signal file deleted after processing.

```bash
ls "$SIGNAL_DIR"
```

**PASS**: Empty directory.

---

## Step 6 — Live Hook Integration (Optional)

**Goal**: Hook fires automatically on real session end.

The session-end hook must be in `~/.claude/settings.json`. If not deployed
via home-manager, human can add temporarily:

```json
{
  "hooks": {
    "SessionEnd": [{
      "type": "command",
      "command": "CCS_SIGNAL_DIR=/tmp/ccs-hook-test bash <project>/scripts/session-end-hook.sh"
    }]
  }
}
```

1. Start a short Claude session (`claude` → ask one question → `/exit`).
2. Check: `ls -la /tmp/ccs-hook-test/`

**PASS**: `.available` file appears with session ID.

---

## Completion

Present results table:

```
| Step | Result | Notes |
|------|--------|-------|
| 1    |        |       |
| 2    |        |       |
| 3    |        |       |
| 4    |        |       |
| 5    |        |       |
| 6    |        |       |
```

**If steps 1-5 PASS**: Phase 2c.2 gate can be checked off in WORKPLAN.
**If step 6 also PASS**: Full capture→process loop confirmed.
