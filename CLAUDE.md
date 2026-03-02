# Claude Conversation Sync

## Before You Start

**Read [`docs/progress.md`](docs/progress.md) first.** It contains handoff notes from
previous agents — what was done, gotchas encountered, and suggested next steps.

## When You Finish

1. **Update documentation** to reflect your changes:
   - `docs/design.md` — if you changed architecture, types, or data formats
   - `docs/plan.md` — if you completed phases or discovered new work
   - `docs/decisions/` — create an ADR if you made a significant technical decision
   - `CLAUDE.md` — if project structure or conventions changed

2. **Append to [`docs/progress.md`](docs/progress.md)** with:
   - Date and what you accomplished
   - Any gotchas or surprises
   - Suggested next steps for the next agent

3. **Commit everything together** — code, docs, and progress in one atomic commit

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

## Documentation

- [`docs/design.md`](docs/design.md) — full system design, domain model, types
- [`docs/plan.md`](docs/plan.md) — phased implementation plan
- [`docs/decisions/`](docs/decisions/) — architecture decision records

## Project Structure

```
├── app/                    # Executable entry points
├── src/                    # Library code
├── prompts/                # LLM prompt templates
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

## Conventions

- Follow type signatures from design document
- Keep ACL types (ClaudeSessionEntry, EventLogEntry) at boundaries
- Prompts live in `prompts/`, loaded at runtime
- Use `record-event` subprocess pattern for LLM → event recording

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
