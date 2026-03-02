# Implementation Plan

## Phases Overview

```
Phase 0: Spike ─────────────────────────────────────────────────┐
    │                                                           │
    ▼                                                           │
┌───────────────────────────────────────────────────────┐       │
│              Parallel Workstreams                      │       │
├─────────────────┬─────────────────┬───────────────────┤       │
│   Capture       │   Tooling       │   Prompts         │       │
│   (Phase 1)     │   (Phase 2a)    │   (Phase 2b)      │       │
├─────────────────┼─────────────────┼───────────────────┤       │
│ SessionEnd hook │ Pre-filter fn   │ Extraction prompt │       │
│ PreCompact hook │ record-event CLI│ Synthesis prompt  │       │
│ Project ID logic│ Aggregation job │ Plan diff prompt  │       │
│ Signal format   │   skeleton      │                   │       │
└────────┬────────┴────────┬────────┴─────────┬─────────┘       │
         │                 │                  │                 │
         └────────────────►├◄─────────────────┘                 │
                           │                                    │
                    Integration (Phase 2c)                      │
                           │                                    │
                           ▼                                    │
                    Phase 3: Status Synthesis                   │
                           │                                    │
                           ▼                                    │
                    Phase 4: Retrieval                          │
                           │                                    │
                           ▼                                    │
                    Phase 5: Work-specific (optional)           │
                           │                                    │
                           ▼                                    │
                    Phase 6: Archival (deferred)                │
                                                                │
◄───────────────────── Validation gates ────────────────────────┘
```

---

## Phase 0: Spike

**Goal**: Validate the extraction approach before building infrastructure.

**Work**:
- Run pre-filter script on 3-5 real sessions
- Run extraction prompt manually via `claude -p`
- Evaluate extracted events for usefulness

**Validation gate**: Are extracted events useful 2 weeks later? If not, iterate prompt.

**Deliverables**:
- Validated extraction prompt
- Sample extracted events for reference

---

## Phase 1: Capture

**Goal**: Reliably capture session artifacts when sessions end.

**Work**:
- `SessionEnd` hook: copy JSONL, write `.available` signal
- `PreCompact` hook: copy pre-compaction snapshot
- Project identification logic (git remote, .claude-project, fallback)
- Signal format definition

**Validation gate**: Run 5 sessions, verify all artifacts captured.

**Deliverables**:
- Hook scripts (Python or Haskell)
- Project identification module
- Signal file format documented

---

## Phase 2a: Tooling

**Goal**: Build processing infrastructure.

**Work**:
- Pre-filter function (JSONL → plain text)
- `record-event` CLI tool
- Aggregation job skeleton (quiet period, locking, signal consumption)

**Dependencies**: Signal format from Phase 1

**Deliverables**:
- `ccs filter` command
- `record-event` command
- `ccs aggregate` command skeleton

---

## Phase 2b: Prompts

**Goal**: Design and test all LLM prompts.

**Work**:
- Refine extraction prompt based on Phase 0 learnings
- Design synthesis prompt (EVENTS → STATUS.md)
- Design plan diff prompt

**Dependencies**: Pre-filter output format

**Deliverables**:
- `prompts/session-extraction.md`
- `prompts/status-synthesis.md`
- `prompts/plan-diff.md`

---

## Phase 2c: Integration

**Goal**: Wire together capture, tooling, and prompts.

**Work**:
- Connect aggregation job to hooks
- Wire extraction prompt invocation
- Write EVENTS.jsonl output

**Validation gate**: Process a real session end-to-end, inspect EVENTS.jsonl.

**Deliverables**:
- Working end-to-end pipeline
- EVENTS.jsonl with real extracted events

---

## Phase 3: Status Synthesis

**Goal**: Generate useful STATUS.md from accumulated events.

**Work**:
- Wire synthesis prompt to aggregation job
- Rewrite STATUS.md at end of each aggregation run

**Validation gate**: Read STATUS.md cold. Does it help understand project state?

**Deliverables**:
- STATUS.md generation
- 4-question format output

---

## Phase 4: Retrieval

**Goal**: Surface context at session start.

**Work**:
- `UserPromptSubmit` hook (detect project, offer context)
- `/context` slash command

**Validation gate**: Start a session, is offered context helpful?

**Deliverables**:
- Context injection hook
- `/context` skill

---

## Phase 5: Work-specific (Optional)

**Goal**: Add work-context features.

**Work**:
- Skill gap tagging prompt
- Growth signals section in STATUS.md
- Integration with `self-review-signal`

---

## Phase 6: Archival (Deferred)

**Goal**: Manage EVENTS.jsonl growth.

**Work**:
- Monthly archival job
- Archive entry format
- `--deep` retrieval flag

---

## Parallelization Summary

After Phase 0:

| Stream | Can Start | Blocked By |
|--------|-----------|------------|
| Phase 1 (Capture) | Immediately | — |
| Phase 2a (Tooling) | Immediately | Signal format (light) |
| Phase 2b (Prompts) | Immediately | Pre-filter format (light) |
| Phase 2c (Integration) | After 1, 2a, 2b | All parallel streams |
| Phase 3+ | After 2c | Integration complete |
