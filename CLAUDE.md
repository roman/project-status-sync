# Claude Conversation Sync

## Before You Start

**Read [`WORKPLAN.md`](WORKPLAN.md) first.** It is the single source of truth for:
- Current phase and status
- What work is done, in progress, or blocked
- Session handoff notes from previous agents

For deeper context on specific tasks, check [`notes/handoffs/`](notes/handoffs/).

## Goal

Make Claude useful across sessions by giving it awareness of previous work on a project —
what was decided, what's in flight, what was learned — without requiring manual context
sharing.

Claude Code stores conversations in `~/.claude/projects/` as opaque JSONL files. This
project extracts meaningful events from those conversations, maintains a living project
status document, and injects relevant context at session start.

## Architecture

Three bounded contexts communicating via filesystem:

```
Capture ──(signals)──► Processing ──(EVENTS.jsonl + STATUS.md)──► Retrieval
```

- **Capture**: Hooks triggered by Claude Code lifecycle (fast, no LLM)
- **Processing**: Aggregation job that extracts events and synthesizes status (async, LLM)
- **Retrieval**: Surfaces context at session start (read-only)

## Session Workflow

### Session Size

Keep sessions **short and focused**. Each session should produce 1-2 good commits, then exit.

- If a chunk is too large, split it across sessions
- Exit cleanly before context exhausts
- Don't try to do everything in one session

### Research Before Implementation

Each phase MUST begin with research before code is written:

- Research goes into committed files under `notes/`
- Do NOT rely on context window for research — it's lost on restart
- Do NOT begin implementing until research is committed

### End-of-Session Gate (Non-Negotiable)

Before wrapping up, verify ALL of these:

- [ ] `WORKPLAN.md` phase index is current (status updated)
- [ ] Current phase progress checkboxes reflect actual state
- [ ] Handoff notes added to current phase section
- [ ] `progress.log` has entry for completed work
- [ ] All doc updates committed alongside code
- [ ] No orphaned TODOs — anything deferred is tracked

### Progress Logging

After completing each chunk, append a timestamped line to `progress.log`:

```
YYYY-MM-DD HH:MM — Phase X.Y: brief description of what was done
```

- APPEND only — never rewrite the file
- Single-line entries for `tail -f` monitoring
- Also log gate pass/fail results

## Documentation

- [`docs/design.md`](docs/design.md) — full system design, domain model, types
- [`docs/plan.md`](docs/plan.md) — original phased plan (WORKPLAN.md is the live version)
- [`docs/decisions/`](docs/decisions/) — architecture decision records
- [`notes/`](notes/) — research docs and session handoffs

## Project Structure

```
├── app/                    # Executable entry points
├── src/                    # Library code
├── prompts/                # LLM prompt templates
├── scripts/                # Shell scripts (pre-filter, etc.)
├── notes/                  # Research and handoff docs
│   └── handoffs/           # Per-task handoff documents
├── beads/.beads/           # Issue tracker
└── nix/
    ├── packages/           # Haskell package derivation
    ├── modules/home-manager/  # home-manager module
    └── devenvs/            # Development environment
```

## Development

```bash
nix develop              # Enter dev shell
cabal build              # Build
cabal test               # Run tests
cabal run ccs -- --help  # Run CLI
```

## Implementation Language

Haskell. Type-driven design from the plan translates directly to code.

## Key Types

See design document for full type tree. Core types:

- `SessionEvent` — extracted observation with tag and text
- `SessionReport` — in-memory aggregate of events for one session
- `AvailabilitySignal` — marker file indicating session ready for processing
- `ProjectStatus` — synthesized STATUS.md content

## Coding Conventions

- Follow type signatures from design document
- Keep ACL types (ClaudeSessionEntry, EventLogEntry) at boundaries
- Prompts live in `prompts/`, loaded at runtime
- Use `record-event` subprocess pattern for LLM → event recording

## Safety

- No destructive operations (`rm -rf`, `git reset --hard`, force push)
- No modifications to files outside this project directory
- No writing credentials or secrets to disk

## Commit Messages

Follow [Conventional Commits](https://www.conventionalcommits.org/) with the 50/72 rule:

- **Title**: max 50 characters, format: `type: description`
- **Body**: wrap at 72 characters, explain *why* not *what*

Types: `feat`, `fix`, `refactor`, `docs`, `test`, `chore`

```
feat: add session event extraction

The extraction prompt identifies decisions, blockers, and next steps
from conversation transcripts. This enables cross-session context
without manual note-taking.
```

## Ralph Mode (Headless Operation)

If running in headless mode (`claude -p`), read `RALPH.md` for additional instructions
about message inbox checking and clean exit protocol.

*(RALPH.md to be created when headless operation is needed)*
