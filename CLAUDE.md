# Claude Conversation Sync

## Before You Start (MANDATORY)

**Read [`WORKPLAN.md`](WORKPLAN.md) FIRST.** Do not write any code until you have:

1. Read WORKPLAN.md completely
2. Identified the current phase and its status
3. Found the most recent handoff notes
4. Determined what work to pick up next

WORKPLAN.md is the single source of truth for:
- Current phase and status
- What work is done, in progress, or blocked

Session handoff notes live in [`notes/handoffs/`](notes/handoffs/). WORKPLAN.md links to them via `See:` references.

## Documentation Before Every Commit (NON-NEGOTIABLE)

**TRIGGER**: When user says "commit", "please commit", or "commit the changes":
1. STOP — do not run `git commit` yet
2. First update: WORKPLAN.md, progress.log, handoff doc
3. Then stage ALL files together
4. Then commit

**Every commit includes:**

1. **Code changes** — the actual implementation
2. **WORKPLAN.md** — update progress checkboxes, phase status
3. **progress.log** — append a timestamped entry
4. **Handoff document** — create/update `notes/handoffs/YYYY-MM-DD-topic.md`

This is not optional. A commit without documentation updates is incomplete.

## Code Review Before Every Commit (NON-NEGOTIABLE)

After implementation and before committing:

1. **Run `cabal test`** — do not proceed if tests fail
2. **Spawn `code-critic` agent** (via Task tool) to review your changes
3. Address blocker and major severity findings. Ignore stylistic nitpicks.
4. Do not loop more than twice — ship it after two rounds of fixes.

```bash
# Correct workflow:
1. Make code changes
2. Run `cabal test` — do not proceed if tests fail
3. Spawn code-critic agent to review changes (address blocker/major issues, max 2 rounds)
4. Update WORKPLAN.md (progress, status, handoff notes)
5. Append to progress.log
6. Create/update handoff in notes/handoffs/
7. Stage ALL files together
8. Commit with descriptive message

# WRONG - never do this:
git add src/
git commit -m "implement feature"
# Documentation left for "later" = documentation never happens
```

## Plans Must Be Persisted

If you create a plan during this session (via EnterPlanMode or research):

1. Write it to `docs/plans/YYYY-MM-DD-topic-kebab-case.md`
2. Create a handoff in `notes/handoffs/` referencing the plan
3. Include both in your commit

Plans in the context window are lost on session end. Plans on disk survive.

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
YYYY-MM-DD HH:MM [<session-prefix>] — Phase X.Y: brief description
```

Where `<session-prefix>` is the first 8 characters of the session ID from `.current-session-id`.

To get the session prefix:
```bash
head -c8 .current-session-id 2>/dev/null || echo "unknown"
```

- APPEND only — never rewrite the file
- Single-line entries for `tail -f` monitoring
- Session ID enables linking log entries to conversation transcripts
- Also log gate pass/fail results

## Documentation

- [`docs/design.md`](docs/design.md) — full system design, domain model, types
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

**WARNING**: This project uses devenv, which requires `--impure` for all nix commands.
If you see `error: Failed assertions: devenv was not able to determine the current directory`,
add `--impure` to the command.

```bash
nix develop --impure     # Enter dev shell (--impure required by devenv)
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

If running in headless mode (`claude -p`), read [`RALPH.md`](RALPH.md) for additional
instructions about sandbox environment, test gates, and clean exit protocol.
