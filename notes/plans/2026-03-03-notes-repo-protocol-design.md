# Plan: Async Notes Repository Protocol Prompts

## Problem Statement

For projects where operational docs (WORKPLAN, handoffs) **cannot live in the repo** (work projects, client repos, repos you don't control), we need an external memory system. The Notes repository (Obsidian) becomes the single source of truth for:

- Current project status (STATUS.md)
- Session handoffs (separate files)
- Progress tracking (progress.log)
- Cross-project awareness

## Contrast: iidy-hs (In-Repo) vs Notes Repo (Proposed)

### File-by-File Comparison

| File | iidy-hs (In-Repo) | Notes Repo (Proposed) | Key Differences |
|------|-------------------|----------------------|-----------------|
| **WORKPLAN.md** | Central operational doc with phases, gates, chunks, session log, handoff notes inline | **Not used** — replaced by STATUS.md | WORKPLAN is prescriptive (plan); STATUS is descriptive (state) |
| **STATUS.md** | Not present in iidy-hs | **Primary document** — 4-question format synthesized from conversations | New document type for Notes repo |
| **progress.log** | Append-only, `YYYY-MM-DD HH:MM [session] — summary` | **Same format** | Identical purpose and format |
| **notes/handoffs/*.md** | Written by working agent before commit | Written by summarization agent after session | Different agent, different timing |
| **CLAUDE.md** | In-repo project instructions | Stays in repo (read-only reference) | No change |

### Structural Differences

```
iidy-hs (In-Repo)                      Notes Repo (Proposed)
─────────────────                      ─────────────────────
project/                               {notes_base}/{project}/
├── WORKPLAN.md          ←──┐          ├── STATUS.md          ←── replaces WORKPLAN
│   ├── Phase Index      │             │   ├── Status
│   ├── Gates/Chunks     │ merged      │   ├── Where We're At
│   ├── Session Log      ├──────────►  │   ├── Where We're Going
│   └── Handoff Notes    │             │   ├── What We Know
├── progress.log         ←──┘          │   └── What We Need to Know
├── notes/handoffs/                    ├── progress.log       ←── same format
│   ├── 2026-03-03-topic.md            ├── handoffs/
│   └── 2026-03-02-topic.md            │   ├── 2026-03-03-abc123-topic.md
└── CLAUDE.md                          │   └── 2026-03-02-def456-topic.md
                                       └── (no CLAUDE.md here)
```

### Content Differences

| Aspect | iidy-hs WORKPLAN.md | Proposed STATUS.md |
|--------|---------------------|-------------------|
| **Author** | Working agent (ralph) updates at session end | Summarization agent generates after session |
| **Structure** | Phases with gates, chunks, progress boxes | 4-question format (flat, no phases) |
| **Session Log** | Table in WORKPLAN | Separate progress.log file |
| **Handoffs** | Inline sections in WORKPLAN | Separate files in handoffs/ |
| **Prescriptive** | Yes — "do this next" with checkboxes | No — describes state, not plan |
| **Git tracked** | Yes (in project repo) | Yes (in Notes repo, separate) |

### Handoff Differences

| Aspect | iidy-hs Handoff | Proposed Handoff |
|--------|-----------------|------------------|
| **Author** | Working agent (ralph) writes before commit | Separate summarization agent writes after session |
| **Timing** | End of session, before commit | Post-session (capture hook triggers) |
| **Location** | `notes/handoffs/` in project repo | `handoffs/` in Notes repo |
| **Filename** | `YYYY-MM-DD-topic.md` | `YYYY-MM-DD-{sessionID}-{topic}.md` |
| **Purpose** | Prescriptive task brief for next agent | Descriptive session summary |

### Handoff Structure Contrast

**iidy-hs Handoff** (prescriptive, ~100-500 lines):
```markdown
# {Task Title} — {Brief Description}

**Date**: 2026-03-01
**References**: {file paths, related sessions}

## Context
{Why this work exists, background}

## Instructions for Next Agent
{Detailed step-by-step instructions}
{What to read first, what to analyze, what to plan}

## Codebase Reference
| What | Where |
|------|-------|
| ... | ... |

## Build/Test Commands
{Per CLAUDE.md}

## Delegation Strategy
{Which model for which phase}

## Workflow Instructions
{1. Read this file, 2. Analyze, 3. Plan, 4. Implement}

## Analysis
{Detailed breakdown, tables, code references}

## Chunks
{Specific implementation chunks with checkboxes}

## Progress
{Completed chunks, remaining work}
```

**Proposed Handoff** (descriptive, ~50-150 lines):
```markdown
# Handoff: {Topic}

**Date**: 2026-03-03
**Session**: abc12345

## What Was Done
- {Concrete accomplishments}
- {Decisions made}

## What's Next
- {Next steps from events}
- {Unresolved blockers}

## Notes
- {Context, warnings, gotchas}
```

**Key Difference**: iidy-hs handoffs are **task briefs** that tell the next agent exactly what to do. Proposed handoffs are **session summaries** that describe what happened. The prescriptive guidance lives in STATUS.md ("Where We're Going") rather than in each handoff.

### Agent Architecture Difference

```
iidy-hs (Single Agent)                 Notes Repo (Two Agents)
──────────────────────                 ───────────────────────

┌─────────────────────┐                ┌─────────────────────┐
│   Ralph (working)   │                │   Working Agent     │
│                     │                │                     │
│  1. Do work         │                │  1. Do work         │
│  2. Update WORKPLAN │                │  2. Exit            │
│  3. Write handoff   │                └─────────────────────┘
│  4. Commit          │                          │
│  5. Exit            │                          ▼ capture hook
└─────────────────────┘                ┌─────────────────────┐
                                       │ Summarization Agent │
                                       │                     │
                                       │  1. Read convo      │
                                       │  2. Write STATUS.md │
                                       │  3. Write handoff   │
                                       │  4. Append progress │
                                       └─────────────────────┘

Next session:                          Next session:
- Ralph reads WORKPLAN                 - Working agent reads STATUS.md
  from project repo                      + handoffs from Notes repo
```

### What's Preserved

- **progress.log format** — identical append-only format with session IDs
- **Handoff concept** — separate dated files per session
- **Session continuity** — context available for next session start
- **Project isolation** — one directory per project
- **LLM-generated docs** — both systems use LLM to write docs

### What's Different

| Aspect | iidy-hs | Notes Repo |
|--------|---------|------------|
| **Document author** | Working agent writes docs | Separate summarization agent writes docs |
| **When docs written** | Before commit, end of session | After session ends (capture hook) |
| **Location** | Project repo | Notes repo (external) |
| **Main document** | WORKPLAN.md (prescriptive) | STATUS.md (descriptive) |
| **Next session reads** | WORKPLAN from project repo | STATUS.md + handoffs from Notes repo |

### Why These Differences?

| iidy-hs Context | Notes Repo Context |
|-----------------|--------------------|
| Can commit to repo | Cannot commit to project repo |
| Working agent has context to write docs | Working agent exits; summarization agent reads conversation |
| Prescriptive plan (phases/gates) useful | Just need state awareness |
| Single agent does everything | Separation of concerns: work vs summarization |

## Design: Mirrored Structure in Notes Repo

### Directory Structure (per project)

```
{base_path}/              # Configured via module option
└── {project-name}/
    ├── EVENTS.jsonl      # Append-only structured events (source of truth)
    ├── STATUS.md         # Synthesized status document
    ├── handoffs/
    │   ├── 2026-03-03-abc12345-auth-middleware.md
    │   └── 2026-03-02-def67890-api-refactor.md
    └── progress.log      # Append-only session log
```

This mirrors the in-repo pattern (iidy-hs) but lives in Notes repo.

### STATUS.md Structure

```markdown
# {Project Name}

> One-line description

## Status

**Phase**: {current phase or work focus}
**Last Session**: {date} — {session_id}
**Blockers**: {list or "None"}

## Recent Handoffs

For detailed session context, see:
- [[handoffs/2026-03-03-abc12345-auth-middleware|Auth Middleware (2026-03-03)]]
- [[handoffs/2026-03-02-def67890-api-refactor|API Refactor (2026-03-02)]]

## Where We're At

- Current work items with context
- Recent decisions made
- What's working / what's not

## Where We're Going

- Immediate next steps
- Open questions needing answers
- Planned phases (if applicable)

## What We Know

- Key decisions with rationale
- Technical constraints discovered
- Context that persists across sessions

## What We Need to Know

- Open questions
- Blockers requiring human input
- Uncertainties to resolve
```

**Note**: The "Recent Handoffs" section uses Obsidian wikilinks to reference handoff files. This gives the working agent direct pointers to detailed session context. The synthesis prompt should include the 2-3 most recent handoff links.

### Handoff Structure (individual files)

**Filename format**: `YYYY-MM-DD-{sessionID}-{topic}.md`

Examples:
- `2026-03-03-abc12345-auth-middleware.md`
- `2026-03-02-def67890-api-refactor.md`

```markdown
# Handoff: {Topic as Title}

**Date**: 2026-03-03
**Session**: abc12345

## What Was Done

- Completed X
- Investigated Y

## What's Next

- Start Z
- Resolve blocker W

## Notes

- Key decision: chose A over B because...
- Found issue with C, deferred to next session
```

### progress.log Format

```
2026-03-03 14:30 [abc12345] — Implemented X, resolved blocker Y
2026-03-02 10:15 [def67890] — Research phase, decided on approach Z
```

## Configuration

### Module Options

```nix
{
  services.claude-conversation-sync = {
    enable = true;

    # Base path for Notes repo output
    notesBasePath = "~/Notes/01 Projects";  # or absolute path

    # Org/company mappings
    orgMappings = {
      "git.musta.ch/airbnb" = "Airbnb";
      "github.com/anthropics" = "Anthropic";
    };

    # Override specific projects
    projectOverrides = {
      "git.musta.ch/airbnb/legacy" = "Airbnb/archived/legacy";
    };
  };
}
```

### Project Key → Notes Path Derivation

**Project key format:**
```
{git_remote}/{subpath}
```

**Derivation logic:**
1. Extract org and repo from git remote
2. Look up org in `orgMappings` (default to org name if not found)
3. For monorepos, append subpath after repo name
4. Check `projectOverrides` for explicit mapping
5. Join: `{notesBasePath}/{mapped_org}/{repo}/{subpath}/`

**Examples:**
```
git.musta.ch/airbnb/ergo                    → ~/Notes/01 Projects/Airbnb/ergo/
git.musta.ch/airbnb/ergo/projects/cell-ctrl → ~/Notes/01 Projects/Airbnb/ergo/cell-ctrl/
github.com/user/repo                        → ~/Notes/01 Projects/user/repo/
```

## Reconciliation with Existing Design

### EVENTS.jsonl: Keep It

After analysis, the two-stage approach (extract → synthesize) is the right design:

1. **Lossless history**: EVENTS.jsonl is the authoritative record. STATUS.md can always be regenerated. Direct synthesis creates a "telephone game" effect where details are lost through successive summarizations.

2. **Single responsibility**: Extraction prompt identifies observations. Synthesis prompt presents them. Each can be improved independently.

3. **Search capability**: Structured events enable `/context --tag decision`, time-series analysis, and evidence collection.

4. **Archival**: Phase 6 (Archival) assumes monthly rotation with summary pointers. This architecture enables graceful growth management.

### Notes Repo = Different Output Path, Same Architecture

The Notes repo use case does NOT require a different architecture. It requires a different **output path**:

```
# In-repo project:
~/Projects/self/project-name/
  ├── EVENTS.jsonl
  └── STATUS.md

# Notes repo project:
{notesBasePath}/{project}/
  ├── EVENTS.jsonl
  ├── STATUS.md
  ├── handoffs/
  └── progress.log
```

The extraction → synthesis flow works identically; only the output path differs.

### Updated Processing Flow

```
Session End
    │
    ▼
Capture Hook fires
    │
    ├── Read session conversation (JSONL → filtered text)
    ├── Derive project key from git remote + cwd
    ├── Map to Notes path via config
    │
    ▼
1. Run session-extraction.md prompt (EXISTING)
    │
    ├── Append events to EVENTS.jsonl
    │
    ▼
2. Run handoff-generation.md prompt
    │
    ├── Input: This session's events only
    ├── Output: handoff content + derived topic
    ├── Write handoffs/{date}-{sessionID}-{topic}.md
    │
    ▼
3. Append progress.log entry
    │
    ▼
4. Run status-synthesis.md prompt (LAST)
    │
    ├── Input: EVENTS.jsonl + list of handoff files (including the one just created)
    └── Write STATUS.md (with wikilink to new handoff)
```

**Why this order?** STATUS.md needs to reference the handoff that was just created. By running it last, we know the handoff filename and can include the wikilink.

## Prompts Needed

### 1. `session-extraction.md` (EXISTS)

Already implemented. Extracts events from conversation with tags:
- `decision`, `question`, `next`, `blocker`, `resolved`, `context`, `initiative`

Output: `record-event` calls that append to EVENTS.jsonl

### 2. `status-synthesis.md` — Synthesize from Events

**Purpose:** Generate STATUS.md from accumulated EVENTS.jsonl

**Trigger:** After extraction completes

**Input:**
```
# Project: {name}
# Session: {session_id}
# Date: {date}

## All Events (from EVENTS.jsonl)
{all_events_jsonl}

## Recent Handoff Files (for linking)
{list of recent handoff filenames with dates and topics}
```

**Output:** STATUS.md with 4-question format + Recent Handoffs section

**Key Instructions:**
- Synthesize from the full event history, not just recent session
- Include "Recent Handoffs" section with wikilinks to 2-3 most recent handoffs
- Group related events into coherent narratives
- Identify what's still relevant vs what's resolved
- Be concise — aim for quick re-orientation

### 3. `handoff-generation.md` — Handoff Document Prompt

**Purpose:** Generate handoff file for this session

**Trigger:** After extraction completes

**Input:**
```
# Project: {name}
# Session: {session_id}
# Date: {date}

## This Session's Events (filtered from EVENTS.jsonl)
{events_from_this_session}
```

**Output:** Handoff markdown file following structure above

**Filename:** `{date}-{sessionID}-{topic}.md`
- Date: YYYY-MM-DD
- SessionID: full session ID from conversation metadata
- Topic: kebab-case summary of primary work (LLM-derived from events, e.g., `auth-middleware`, `api-refactor`)

### 4. `progress-entry.md` — Progress Log Entry

**Purpose:** Generate single-line progress.log entry

**Trigger:** After extraction completes

**Input:**
```
# Session: {session_id}
# Date: {date}

## This Session's Events
{events_from_this_session}
```

**Output:** Single line in format: `{date} {time} [{session_prefix}] — {summary}`

*Note: This is simple enough it could be a template rather than full LLM call. Could derive topic from events directly.*

### 5. Context Injection (via CLAUDE.md, not a prompt)

**Method:** Project CLAUDE.md or user's ~/.claude/CLAUDE.md includes instructions telling the working agent where to find context.

**Example CLAUDE.md snippet:**
```markdown
## Project Context

Before starting work, read the project status from Notes:
- STATUS.md: ~/Notes/Projects/Airbnb/ergo/STATUS.md
- Recent handoffs: ~/Notes/Projects/Airbnb/ergo/handoffs/

These files contain context from previous sessions.
```

**No separate prompt needed** — the working agent reads files directly based on CLAUDE.md instructions.


## Implementation Steps

1. [ ] Add module options for notesBasePath, orgMappings, projectOverrides
2. [ ] Implement project key → Notes path derivation
3. [ ] Create `prompts/handoff-generation.md` (generate from session events)
4. [ ] Create `prompts/progress-entry.md` (or template)
5. [ ] Create `prompts/status-synthesis.md` (synthesize from EVENTS.jsonl + handoff refs)
6. [ ] Update capture hook flow (in order):
   1. Run session-extraction.md (exists) → append to EVENTS.jsonl
   2. Run handoff-generation.md → write handoffs/{date}-{sessionID}-{topic}.md
   3. Append progress.log entry
   4. Run status-synthesis.md (last) → write STATUS.md with handoff link
7. [ ] Document CLAUDE.md pattern for context reference
8. [ ] Test with real session on work project

## Verification

- [ ] Run extraction on recent session, verify EVENTS.jsonl entries
- [ ] Run synthesis on EVENTS.jsonl, verify STATUS.md quality
- [ ] Verify handoff files created with correct filename format (date-sessionID-topic)
- [ ] Verify progress.log accumulates entries
- [ ] Test path derivation: git.musta.ch/airbnb/ergo → {notesBasePath}/Airbnb/ergo/
- [ ] Verify working agent can find STATUS.md via CLAUDE.md reference
- [ ] Test multi-session accumulation: events from session 2 should include session 1 context

## Example: status-synthesis.md Prompt (Draft)

```markdown
# Status Synthesis

You are generating a project status document from accumulated events.

## Input

You receive:
1. Project name and session metadata
2. All events from EVENTS.jsonl (structured observations across all sessions)
3. List of recent handoff files (for linking)

Each event has: date, session, tag (decision/question/next/blocker/resolved/context/initiative), text

## Task

Synthesize events into STATUS.md with these sections:

1. **Status**: Current phase, last session, blockers
2. **Recent Handoffs**: Wikilinks to 2-3 most recent handoff files
3. **Where We're At**: Current state from recent events
4. **Where We're Going**: Next steps (from `next` tags, unresolved `blocker` tags)
5. **What We Know**: Key decisions (from `decision` tags), context
6. **What We Need to Know**: Open questions (from `question` tags)

## Guidelines

- Include "Recent Handoffs" section with Obsidian wikilinks: `[[handoffs/filename|Display Text]]`
- Synthesize across all events, not just recent session
- Distinguish resolved vs unresolved items (check for `resolved` tags)
- Group related events into coherent narratives
- Be concise — aim for quick re-orientation (under 500 words total)
- Write for someone starting a new session in 2 weeks
```

## Example: handoff-generation.md Prompt (Draft)

```markdown
# Handoff Generation

Generate a handoff document from this session's extracted events.

## Input

You receive:
1. Session metadata (date, session ID)
2. This session's events (filtered from EVENTS.jsonl by session ID)

Each event has: tag (decision/question/next/blocker/resolved/context/initiative), text

## Output

Generate a handoff document with:

### What Was Done
- Concrete accomplishments (from events)
- Key decisions made (from `decision` tags)
- Blockers resolved (from `resolved` tags)

### What's Next
- Specific next steps (from `next` tags)
- Unresolved blockers (from `blocker` tags without matching `resolved`)

### Notes
- Important context (from `context` tags)
- Open questions (from `question` tags)

Also derive a **topic** (kebab-case, 2-4 words) summarizing the primary work for the filename.

## Guidelines

- Be specific — "implemented auth middleware" not "made progress"
- If blocked, state clearly what's needed to unblock
- Keep under 200 words
```
