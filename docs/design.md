---
project: claude-conversation-sync
status: in-design
created: 2026-02-26
updated: 2026-03-08
repo: ~/Projects/self/claude-conversation-sync
---

# Claude Conversation Sync

## Table of Contents

- [Goal](#goal)
- [Context](#context)
- [Domain Model](#domain-model)
  - [Ubiquitous Language](#ubiquitous-language)
  - [Bounded Contexts](#bounded-contexts)
  - [Event Storm](#event-storm)
- [System Design](#system-design)
  - [Capture](#capture)
  - [Processing](#processing)
  - [Retrieval](#retrieval)
  - [Project Identification](#project-identification)
- [Data Formats](#data-formats)
  - [EVENTS.jsonl](#eventsjsonl)
  - [STATUS.md](#statusmd)
  - [Handoffs](#handoffs)
  - [progress.log](#progresslog)
  - [Archive Entry](#archive-entry)
- [LLM Prompts](#llm-prompts)
  - [Pre-filtering](#session-transcript-pre-filtering)
  - [Prompt Inventory](#prompt-inventory)
- [Type-Driven Design](#type-driven-design)
  - [Approach](#approach-stdout-parsing)
  - [Types](#types)
  - [Resolved Design Decisions](#resolved-design-decisions)
- [Implementation](#implementation)
  - [Output Structure](#output-structure)
  - [Module Options](#module-options)
- [Verification](#verification)
- [Documentation References](#documentation-references)

---

## Goal

Make Claude useful across sessions by giving it awareness of previous work on a project —
what was decided, what's in flight, what was learned — without requiring manual context
sharing.

Claude Code stores conversations in `~/.claude/projects/` as opaque JSONL files. This
project extracts meaningful events from those conversations, maintains a living project
status document, and surfaces relevant context at session start.

---

## Context

### The Problem

Claude Code conversations are stored as `.jsonl` files under opaque directory names
(e.g., `-Users-roman-gonzalez-Documents-PARA`) with UUID filenames. This makes
conversations:

- Hard to find and navigate
- Disconnected from any knowledge base
- At risk of detail loss when compaction rewrites files

### Two Operating Modes

Projects fall into two categories based on where documentation can live:

| Mode | Example | Where docs live |
|------|---------|-----------------|
| **In-repo** | Personal projects, OSS | Project repo itself |
| **Notes repo** | Work projects, client repos | External Notes repository |

For in-repo projects, operational docs (WORKPLAN.md, handoffs) live alongside the code.
For Notes repo projects, we need an external memory system — the Notes repository becomes
the single source of truth for project state.

This system handles both modes through configurable output paths.

### Two-Agent Architecture

```
┌─────────────────────┐
│   Working Agent     │
│                     │
│  1. Read STATUS.md  │
│  2. Do work         │
│  3. Exit            │
└─────────────────────┘
          │
          ▼ SessionEnd hook
┌─────────────────────┐
│ Summarization Agent │
│                     │
│  1. Read convo      │
│  2. Extract events  │
│  3. Write handoff   │
│  4. Update STATUS   │
└─────────────────────┘
```

The working agent focuses on the task. A separate summarization agent (triggered by
capture hooks) reads the conversation and generates documentation. This separation
means:

- Working agent doesn't need to remember to document
- Documentation is consistent and structured
- Works for repos where the working agent can't commit

---

## Domain Model

### Ubiquitous Language

#### Session
A conversation with Claude Code. Tied to a Project, identified by an opaque ID assigned
by Claude Code. Never explicitly ends — it is abandoned when the user stops continuing
it. May grow via `claude --continue`, which appends new messages under the same identity.

#### Project
The unit of work a Session belongs to. Usually backed by a git repository. Has two
first-class identifiers:

- **Key** — canonical, opaque, derived from git remote URL + subpath. Stable across
  clones. Used for identity and as the on-disk partition key.
- **Name** — human-readable, first-class. Used in STATUS.md headers, EVENTS.jsonl
  entries, and LLM prompts.

#### Availability Signal
A file written by the Capture hook when a Session ends. Carries the Session identity,
transcript path, and working directory. The timestamp (from mtime) distinguishes a fresh
exit from a `--continue` resumption. Watched by the aggregation job.

#### Quiet Period
A configurable window during which no new Availability Signals arrive. The aggregation
job only processes when the newest signal is older than the threshold. Separates "user
stepped away momentarily" from "user has moved on." Multiple sessions ending close
together are batched naturally.

#### SessionEvent
A single meaningful observation extracted from a Session. Has:

- **Tag** — a validated text label from a fixed vocabulary; classifies the observation
- **Text** — the observation stated in plain language
- **Source** — where it came from (always `conversation` in current design)

On disk: one line in `EVENTS.jsonl`, self-contained with Session identity, Project, and
date. In memory: a component of a `SessionReport`.

#### SessionReport
The in-memory aggregate produced when processing a Session. Groups all SessionEvents for
one Session. Never serialized as a whole — flattened to individual EVENTS.jsonl lines.

#### Handoff
A per-session summary document. Describes what was done and what's next. Lives in
`handoffs/` directory. Filename includes date, session ID, and topic slug.

#### Project Status
A human-readable synthesis of where a Project stands. Answers: where are we, where are
we going, what do we know, what do we need to know. Stored as `STATUS.md`. Rebuilt from
scratch on every processing run — always fresh synthesis, not accumulation.

#### Archival
The process of moving old SessionEvents out of `EVENTS.jsonl` into separate archive
files. Keeps the main log manageable. Produces an **Archive Entry** (pointer) and an
**Archive File** (the moved events).

---

### Bounded Contexts

Three bounded contexts, communicating exclusively via the filesystem. Each evolves
independently as long as file format contracts are honoured.

```
Capture ──(signals + JSONL)──► Processing ──(EVENTS + STATUS + handoffs)──► Retrieval
```

#### Capture
Fast, synchronous, no LLM calls. Triggered by Claude Code lifecycle hooks.

- **Language**: session, transcript, availability signal
- **Responsibility**: preserve raw session artifacts when a Session exits
- **Produces**: `.available` signal file
- **Rule**: stays cheap — write signal, nothing more

#### Processing
Async, intelligent, owns the aggregates. Triggered by availability signals + quiet period.

- **Language**: project, session event, session report, project status, handoff
- **Responsibility**: derive meaning from raw artifacts; maintain the knowledge base
- **Contains**: Aggregation Job + Archival Job (same language, different schedule)
- **Consumes**: availability signals, Claude session JSONL files
- **Produces**: `EVENTS.jsonl`, `STATUS.md`, `handoffs/*.md`, `progress.log`

#### Retrieval
Read-only, surfacing. Triggered by session start or user command.

- **Language**: context, status, history
- **Responsibility**: surface relevant project knowledge to Claude
- **Consumes**: `STATUS.md`, `handoffs/`, `EVENTS.jsonl`

#### Context Map
- Capture is **upstream** of Processing — format changes in Capture can break Processing
- Processing owns an ACL (parser) at its Capture boundary
- Archival Job lives inside Processing: same aggregates, different schedule

---

### Event Storm

Domain events derived through event storming. Events are named at the domain level —
implementation details absent.

**Jobs:** `Aggregation Job` | `Per-Session Processing` | `Archival Job`

```
Aggregation Job
├── [SessionContentAvailable] ← external trigger (hook)
├── AggregationStarted (or AggregationDeferred if conditions not met)
├── ProjectDetermined
└── PendingSessionsFound (or NoPendingSessionsFound → stop)

Per-Session Processing
├── SessionItemsExtracted
├── HandoffGenerated
├── ProgressEntryAppended
└── SessionRecorded (or SessionSkipped)

Aggregation Job (continued)
└── ProjectStatusUpdated

Archival Job (monthly)
├── ArchivalStarted
├── ExpiredSessionEventsFound (or none → stop)
├── ExpiredSessionEventsSummarized
├── ExpiredSessionEventsArchived
└── ArchivalCompleted
```

---

## System Design

### Capture

| Hook | Action |
|------|--------|
| `SessionEnd` | Write `.available` signal with transcript path and cwd |

The hook reads JSON from stdin (includes `transcript_path`, `session_id`, `cwd`).
**Hooks stay dirt cheap**: write signal file, nothing more. Milliseconds.

The signal file contains:
```json
{"transcript_path": "/path/to/session.jsonl", "cwd": "/path/to/project"}
```

---

### Processing

#### Aggregation Job

**Trigger: Quiet-Period (not immediate)**

The job fires when `.available` signals appear but only processes when files have been
**quiet for 15-30 minutes** (newest `.available` file older than threshold). This
decouples summarization from session close.

**Concurrency Safety**

- **Lock file**: job acquires `{outputPath}/{project}/.lock` before writing
- **Idempotency**: tracks processed signals by (session ID, timestamp)
- **Single STATUS.md rewrite**: done once at end after all pending sessions processed

**Processing Flow**

For each unprocessed `.available` signal:

```
1. Read Claude session JSONL
2. Pre-filter → plain text with role labels
3. Run session-extraction prompt → events
4. Append events to EVENTS.jsonl
5. Run handoff-generation prompt → handoff file
6. Append progress.log entry
7. (After all sessions) Run status-synthesis prompt → STATUS.md
```

**Why this order?** STATUS.md runs last so it can reference the handoff just created
via Obsidian wikilinks.

---

#### Archival Job

Monthly, a separate scheduled job moves old SessionEvents to per-month Archive Files,
leaving an Archive Entry pointer in the main log. This is Phase 6 (deferred).

---

### Retrieval

**Context Injection (session start)**

Working agent reads STATUS.md and recent handoffs based on CLAUDE.md instructions:

```markdown
## Project Context

Before starting work, read the project status:
- STATUS.md: ~/Notes/Projects/Airbnb/ergo/STATUS.md
- Recent handoffs: ~/Notes/Projects/Airbnb/ergo/handoffs/
```

No automatic hook injection — the working agent reads files directly.

**Fallback**: `/context` slash command (Phase 4, deferred)

```
/context                    # STATUS.md + last 3-5 sessions
/context --last 10
/context --since 2026-01
/context --deep             # also search archive files
```

---

### Project Identification

Canonical project identity hierarchy:

1. **Git remote + relative path from git root** — handles monorepos and multi-clone
2. **Last directory component** — fallback for non-git projects

```
# Monorepo:
remote: git@git.musta.ch:airbnb/kube-system.git
cwd: .../kube-system/workload-controller
→ project_key: git.musta.ch/airbnb/kube-system/workload-controller

# Same project, two clones:
/Projects/work/ergo + /tmp/ergo-clean → same remote → same project_key
```

SSH/HTTPS variants normalised to the same key.

**Project Key → Notes Path Derivation**

```
git.musta.ch/airbnb/ergo                    → {notesBasePath}/Airbnb/ergo/
git.musta.ch/airbnb/ergo/projects/cell-ctrl → {notesBasePath}/Airbnb/ergo/cell-ctrl/
github.com/user/repo                        → {notesBasePath}/user/repo/
```

Derivation uses `orgMappings` config to map git hosts/orgs to human-readable names.

---

## Data Formats

### EVENTS.jsonl

Append-only. One JSON object per SessionEvent. Never edited after writing.

```json
{"date":"2026-02-27","session":"abc123","project":"ergo","project_key":"git.musta.ch/airbnb/ergo","tag":"decision","text":"use launchd over systemd for macOS watcher","source":"conversation"}
{"date":"2026-02-27","session":"abc123","project":"ergo","project_key":"git.musta.ch/airbnb/ergo","tag":"resolved","text":"home-manager WatchPaths natively supported","source":"conversation"}
{"date":"2026-02-27","session":"abc123","project":"ergo","project_key":"git.musta.ch/airbnb/ergo","tag":"question","text":"how are sub-agent transcripts named?","source":"conversation"}
{"date":"2026-02-27","session":"abc123","project":"ergo","project_key":"git.musta.ch/airbnb/ergo","tag":"next","text":"wire up SessionEnd hook","source":"conversation"}
```

**SessionEvent tags**: `decision`, `question`, `next`, `blocker`, `resolved`, `context`,
`initiative`

---

### STATUS.md

Living document. Rewritten each aggregation run. Uses 4-question framing with inline
tags and links to recent handoffs.

```markdown
# {Project Name}

> One-line description

## Status

**Phase**: {current phase or work focus}
**Last Session**: {date} — {session_id}
**Blockers**: {list or "None"}

## Recent Handoffs

- [[handoffs/2026-03-03-abc12345-auth-middleware|Auth Middleware (2026-03-03)]]
- [[handoffs/2026-03-02-def67890-api-refactor|API Refactor (2026-03-02)]]

## Where We're At

- Current work items with context
- Recent decisions made #decision

## Where We're Going

- Immediate next steps #next
- Blocked on X #blocker

## What We Know

- Key decisions with rationale #decision
- Technical constraints discovered #context

## What We Need to Know

- Open questions #question
```

---

### Handoffs

Per-session summary documents. Descriptive (what happened), not prescriptive (what to
do next).

**Filename format**: `YYYY-MM-DD-{sessionID}-{topic}.md`

Examples:
- `2026-03-03-abc12345-auth-middleware.md`
- `2026-03-02-def67890-api-refactor.md`

**Structure**:

```markdown
# Handoff: {Topic}

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
- Found issue with C, deferred
```

Target: 50-150 words. Specific accomplishments, not vague progress.

---

### progress.log

Append-only session log. Single line per session for `tail -f` monitoring.

```
2026-03-03 14:30 [abc12345] — Implemented auth middleware, resolved CORS blocker
2026-03-02 10:15 [def67890] — Research phase, decided on approach Z
```

Format: `YYYY-MM-DD HH:MM [{session_prefix}] — {summary}`

---

### Archive Entry

Left in `EVENTS.jsonl` after an Archival run. Replaces the moved SessionEvents.

```json
{
  "date": "2026-01-01/2026-01-31",
  "archived": true,
  "archive": "archive/EVENTS-2026-01.jsonl",
  "summary": "Designed conversation sync architecture, settled on quiet-period trigger..."
}
```

Archive files stored at `archive/EVENTS-YYYY-MM.jsonl`. Searchable via `--deep`.

---

## LLM Prompts

### Session Transcript Pre-filtering

Raw Claude session JSONL files are large (1-16MB) and contain noise: tool results,
progress updates, file snapshots. Pre-filter before LLM invocation.

Extract only `user` and `assistant` message text blocks, output as plain text:

```
USER:
How do I add a new package?

ASSISTANT:
Create a file in nix/packages/ and git add it...
```

**Results**: ~99% size reduction. Plain text is more token-efficient than JSON.

---

### Prompt Inventory

| Prompt | Input | Output |
|--------|-------|--------|
| **Session extraction** | Pre-filtered transcript | `[tag] text` lines on stdout |
| **Handoff generation** | This session's events | Handoff markdown + topic slug |
| **Progress entry** | This session's events | Single-line progress.log entry |
| **Status synthesis** | Full EVENTS.jsonl + handoff list | STATUS.md in 4-question format |
| **Archival summary** | One month of SessionEvents | Summary string for Archive Entry |

**Processing order**: extraction → handoff → progress → status

Status runs last so it can include wikilinks to the handoff just created.

**Key prompt design concerns**:
- Session extraction: signal-to-noise — avoid trivial observations
- Status synthesis: prune stale items, identify what's resolved
- All: determinism — same input → structurally consistent output

**Prompt location**: `prompts/`

---

## Type-Driven Design

### Approach: stdout parsing

The aggregation job calls `claude -p` as a subprocess, piping the prompt and pre-filtered
transcript via stdin. The LLM outputs structured `[tag] text` lines on stdout, which the
Haskell process parses into `SessionEvent` values.

```
Processing job
    │
    ├── pipe prompt+transcript via stdin to: claude -p
    │              │
    │              └── LLM writes to stdout:
    │                    [decision] use launchd over systemd for macOS watcher
    │                    [resolved] home-manager WatchPaths natively supported
    │                    [next] wire up SessionEnd hook
    │
    ├── parseExtractionOutput stdout → [SessionEvent]
    └── append EventLogEntry records to EVENTS.jsonl
```

Simpler than the previously considered `record-event` subprocess pattern: no env var
coordination, no temp files, no extra CLI on `$PATH`. The LLM just writes tagged lines
and the host process parses them.

---

### Types

#### Session Identity

```haskell
newtype SessionId = SessionId Text
```

Text not UUID: we compare and embed in JSON, no arithmetic. The ID comes from the
`.available` filename; stable across `--continue` invocations.

#### Project Identity

```haskell
newtype ProjectKey  = ProjectKey  Text
newtype ProjectName = ProjectName Text
```

Separate newtypes with different semantics:
- `ProjectKey` — opaque, machine-derived, on-disk partition key
- `ProjectName` — human-readable, appears in STATUS.md and prompts

#### Project

```haskell
data Project = Project
  { projectKey  :: ProjectKey
  , projectName :: ProjectName
  , projectPath :: FilePath
  }
```

`projectPath` is the working directory — needed to locate output files.

#### Availability Signal

```haskell
data AvailabilitySignal = AvailabilitySignal
  { signalSessionId         :: SessionId
  , signalProjectPath       :: FilePath
  , signalTimestamp         :: UTCTime
  , signalClaudeSessionPath :: FilePath
  , signalPath              :: FilePath
  }
```

Parsed from the marker file. `signalClaudeSessionPath` is read directly from the
payload — no derivation via Claude's internal conventions.

#### Session Cursor

```haskell
newtype MessageUuid = MessageUuid Text

data SessionCheckpoint = SessionCheckpoint
  { checkpointUuid      :: MessageUuid
  , checkpointTimestamp :: UTCTime
  }

data SessionCursor
  = Beginning
  | From SessionCheckpoint
```

Position in Claude's internal session JSONL. Enables incremental processing.

#### Claude Session Entry (ACL)

```haskell
data ClaudeSessionEntry = ClaudeSessionEntry
  { entryUuid      :: MessageUuid
  , entryTimestamp :: UTCTime
  , entryRaw       :: ByteString
  }
```

ACL type at the Claude file format boundary. Nothing beyond the parser should
reference this type.

#### Event Log Entry (ACL)

```haskell
data EventLogEntry = EventLogEntry
  { eleDate        :: Day
  , eleSessionId   :: SessionId
  , eleProjectKey  :: ProjectKey
  , eleProjectName :: ProjectName
  , eleEvent       :: SessionEvent
  }
```

One per line in EVENTS.jsonl. Read by Archival job.

#### Session Event

```haskell
newtype EventTag    = EventTag    Text
newtype EventSource = EventSource Text

data SessionEvent = SessionEvent
  { eventTag    :: EventTag
  , eventText   :: Text
  , eventSource :: EventSource
  }
```

`EventTag` and `EventSource` are opaque newtypes. Our code never dispatches on their
values — they carry vocabulary the LLM produces and humans consume.

#### Session Report

```haskell
data SessionReport = SessionReport
  { reportSession :: SessionId
  , reportProject :: Project
  , reportDate    :: Day
  , reportEvents  :: NonEmpty SessionEvent
  }
```

In-memory aggregate. Never serialized whole — flattened to EVENTS.jsonl lines.

`reportEvents` is `NonEmpty`: a report without events is not a report.

#### Project Status

```haskell
type ProjectStatus = Text
```

LLM-generated markdown written directly to STATUS.md.

---

### Resolved Design Decisions

| Decision | Resolution |
|----------|------------|
| `.available` file contents | JSON object: `{"transcript_path": "...", "cwd": "..."}` |
| `AvailabilitySignal` bounded context | Processing (ACL boundary), not Capture |
| Staleness and file reading | Read Claude session from original location at processing time |
| `EventTag`/`EventSource` representation | Opaque `newtype Text` wrappers |
| `SessionReport` vs `SessionCheckpoint` | Orthogonal outcomes: `(SessionCheckpoint, Maybe SessionReport)` |
| `ProjectStatus` type | `type ProjectStatus = Text` — LLM-generated, we don't parse |

---

## Implementation

### Output Structure

```
{outputPath}/
  {project-name}/
    STATUS.md
    EVENTS.jsonl
    progress.log
    .lock                                    # transient
    handoffs/
      2026-03-03-abc12345-topic.md
      2026-03-02-def67890-topic.md
    archive/
      EVENTS-YYYY-MM.jsonl
```

---

### Module Options

Unified home-manager module: `programs.project-status-sync`. Enabling it registers both the
SessionEnd hook (capture) and a periodic timer service (processing). Asserts
`programs.claude-code.enable` is true. Replaces the standalone `ccs-session-end-hook` module.

```nix
programs.project-status-sync = {
  enable = lib.mkEnableOption "session capture hook + periodic ccs aggregation";

  # The ccs package (prompts embedded in binary via file-embed)
  package = lib.mkOption {
    type = lib.types.package;
    default = inputs.self.packages.${system}.ccs;
  };

  # Signal directory (shared between hook and aggregation service)
  signalDir = lib.mkOption {
    type = lib.types.str;
    default = "${config.xdg.stateHome}/ccs/signals";
  };

  # Output directory (required — depends on user's setup)
  outputDir = lib.mkOption {
    type = lib.types.str;
    description = "Output directory for EVENTS.jsonl, STATUS.md, handoffs, progress.log";
    example = "/home/user/Notes/01 Projects";
  };

  # Map git hosts/orgs to human-readable names (blocked on CLI support)
  orgMappings = lib.mkOption {
    type = lib.types.attrsOf lib.types.str;
    default = {};
    example = {
      "git.musta.ch/airbnb" = "Airbnb";
      "github.com/anthropics" = "Anthropic";
    };
  };

  # Override specific project output paths (blocked on CLI support)
  projectOverrides = lib.mkOption {
    type = lib.types.attrsOf lib.types.str;
    default = {};
    example = {
      "git.musta.ch/airbnb/legacy" = "Airbnb/archived/legacy";
    };
  };

  # Quiet period before processing (minutes)
  quietPeriodMinutes = lib.mkOption {
    type = lib.types.int;
    default = 20;
  };

  # Timer interval (minutes)
  intervalMinutes = lib.mkOption {
    type = lib.types.int;
    default = 5;
  };

  # LLM command (e.g. "claude" or "airchat")
  llmCommand = lib.mkOption {
    type = lib.types.str;
    default = "claude";
  };

  # LLM command arguments
  # Default: ["-p"] (for "claude -p")
  # Work example: ["claude" "--" "-p"] (for "airchat claude -- -p")
  llmArgs = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [ "-p" ];
  };
};
```

#### What the Module Produces

**1. SessionEnd hook** (capture — writes `.available` signal files):
```nix
# Uses lib.mkAfter for composability with other SessionEnd hooks
programs.claude-code.settings.hooks.SessionEnd = lib.mkAfter [{
  matcher = "";
  hooks = [{
    type = "command";
    command = "CCS_SIGNAL_DIR=${cfg.signalDir} ${hookPkg}/bin/ccs-session-end-hook";
  }];
}];
```

The `ccs-session-end-hook` binary is resolved internally from the same flake inputs
(not a separate option — it is always the matching version of the ccs package).

**2. Periodic timer** (processing — runs `ccs aggregate`):

On Linux — systemd user service + timer:
```nix
systemd.user.services.project-status-sync = {
  Unit.Description = "Project status sync — periodic ccs aggregation";
  Service = {
    Type = "oneshot";
    ExecStart = aggregateCommand;
    Environment = [
      "PATH=${config.home.profileDirectory}/bin:/usr/bin:/bin"
      "HOME=${config.home.homeDirectory}"
    ];
  };
};
systemd.user.timers.project-status-sync = {
  Timer = {
    OnBootSec = "${toString cfg.intervalMinutes}min";
    OnUnitActiveSec = "${toString cfg.intervalMinutes}min";
  };
  Install.WantedBy = [ "timers.target" ];
};
```

On macOS — launchd agent:
```nix
launchd.agents.project-status-sync = {
  enable = true;
  config = {
    Label = "com.ccs.project-status-sync";
    ProgramArguments = [ "${cfg.package}/bin/ccs" "aggregate" ... ];
    StartInterval = cfg.intervalMinutes * 60;
    EnvironmentVariables = {
      PATH = "${config.home.profileDirectory}/bin:/usr/bin:/bin";
      HOME = config.home.homeDirectory;
    };
    StandardOutPath = "/tmp/project-status-sync.log";
    StandardErrorPath = "/tmp/project-status-sync.err";
  };
};
```

#### Aggregate Command

```bash
ccs aggregate \
  --signal-dir ${signalDir} \
  --quiet-minutes ${quietPeriodMinutes} \
  --output-dir ${outputDir} \
  --llm-command ${llmCommand} \
  --llm-arg arg1 --llm-arg arg2 ...
```

Prompts are embedded in the binary via `file-embed` — no `--prompts-dir` needed.
Individual `--extraction-prompt`, `--handoff-prompt`, `--progress-prompt`, and
`--synthesis-prompt` flags are available as optional overrides for development iteration.

#### Notes

- `orgMappings` and `projectOverrides` are spec'd but blocked on CLI support
  (project name derivation in `CCS.Project` does not yet accept mappings)
- Service sets PATH to include `${config.home.profileDirectory}/bin` so the LLM
  command (`claude`, `airchat`, etc.) is found
- API auth is the user's responsibility (claude stores its own credentials)
- The quiet period check + lock file in `ccs aggregate` handle concurrency safety
- `--bypass-claude-check` is not passed — the service runs outside Claude Code,
  so the CLAUDECODE env var check is irrelevant
- Failures are silent — the timer re-fires at the next interval. Future work may
  add `OnFailure=` notification for systemd or equivalent for launchd
- macOS logs to `/tmp/project-status-sync.{log,err}` (cleared on reboot).
  Future work may use a persistent log path

---

## Verification

1. `nix build .#ccs` — package builds
2. `cabal test` — all tests pass
3. Test hook manually with mock stdin
4. Test quiet-period and lock behavior
5. End-to-end: session → signal → processing → EVENTS + STATUS + handoff
6. Verify STATUS.md includes wikilinks to handoffs
7. Verify progress.log accumulates correctly
8. Test project key derivation with orgMappings
9. Monthly archival: events archived, `--deep` finds them

---

## Documentation References

- [Claude Code Hooks](https://docs.anthropic.com/en/docs/claude-code/hooks)
- [Claude Code Configuration](https://docs.anthropic.com/en/docs/claude-code/settings)
- [Claude Code Conversations](https://docs.anthropic.com/en/docs/claude-code/conversations)
- [home-manager launchd.agents](https://nix-community.github.io/home-manager/options.xhtml#opt-launchd.agents)
- [home-manager systemd.user.services](https://nix-community.github.io/home-manager/options.xhtml#opt-systemd.user.services)
