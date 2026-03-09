# Claude Conversation Sync

## Before You Start (MANDATORY)

**Read [`WORKPLAN.md`](WORKPLAN.md) FIRST.** Do not write any code until you have:

1. Read WORKPLAN.md completely
2. Identified the current phase and its status
3. Found the most recent handoff notes
4. Determined what work to pick up next

**Load the `haskell-development-skill`** via the Skill tool before writing any Haskell code.
This is a gate on code writing, not on session start — sessions that only update docs or
reconcile WORKPLAN do not need to load it.

WORKPLAN.md is the single source of truth for:
- Current phase and status
- What work is done, in progress, or blocked

Session handoff notes live in [`notes/handoffs/`](notes/handoffs/). WORKPLAN.md links to them via `See:` references.

## Documentation Before Every Commit (NON-NEGOTIABLE)

**TRIGGER**: When user says "commit", "please commit", or "commit the changes":
1. STOP — do not run `git commit` yet
2. First update relevant docs (see tiers below)
3. Then stage ALL files together
4. Then commit

**Documentation tiers by commit type:**

- **Implementation commits** (touches `src/` or `app/`): WORKPLAN.md + progress.log + handoff doc — all four required
- **Doc-only commits** (WORKPLAN reconciliation, design.md updates): WORKPLAN.md + progress.log
- **Research commits** (notes, proposals): progress.log entry

A commit without its tier's documentation updates is incomplete.

## Spec-First Implementation (NON-NEGOTIABLE)

When implementing a WORKPLAN item:

1. **Quote the item verbatim** — copy the WORKPLAN text into your working context
2. **Identify each requirement** — list what the spec asks for (CLI flag, specific behavior, etc.)
3. **Cross-check approved proposals** — search `notes/proposals/` for APPROVED proposals
   whose `Affects:` line overlaps with the types, modules, or APIs you are about to change.
   If a conflict exists between the WORKPLAN item and an approved proposal:
   - STOP — do not implement
   - Write a proposal amendment or new proposal explaining why the earlier decision
     should be revised
   - Get approval before proceeding

   Examples of changes that require this check:
   - Adding/removing `Maybe` wrappers on record fields (changes API contract)
   - Changing a type from mandatory to optional or vice versa
   - Renaming or removing fields from a shared record
   - Altering the signature of a function used across modules
   - Changing CLI flag semantics (required → optional, new defaults)

4. **Implement to spec** — address each requirement, not just the spirit of the task
5. **If you disagree with the spec** — write a proposal or ask the user. Never silently deviate.

Handoff docs for implementation commits must include a **Spec Compliance** section:

```
## Spec Compliance
WORKPLAN item: "<quoted text>"
- Approved proposals checked: [list or "none affecting these types"]
- Requirement 1: [met/deviated] — explanation
- Requirement 2: [met/deviated] — explanation
```

## Code Review Before Every Code Commit (NON-NEGOTIABLE)

Applies to commits that touch `src/`, `app/`, or `test/`. Doc-only commits skip this.

After implementation and before committing:

1. **Run `cabal test`** — do not proceed if tests fail
2. **Spawn `code-critic` agent** (via Task tool) to review your changes.
   Include the WORKPLAN item text so the critic can verify spec compliance.
3. Address blocker and major severity findings. Ignore stylistic nitpicks.
4. Do not loop more than twice — ship it after two rounds of fixes.

```bash
# Correct workflow (implementation commits):
0. Quote the WORKPLAN item — identify each specific requirement
1. Cross-check notes/proposals/ for APPROVED proposals affecting same types/APIs
2. Make code changes addressing each requirement
3. Run `cabal test` — do not proceed if tests fail
4. Spawn code-critic with WORKPLAN item text (address blocker/major, max 2 rounds)
5. Update WORKPLAN.md (progress, status, handoff notes)
6. Append to progress.log
7. Create/update handoff in notes/handoffs/ (must include Spec Compliance section)
8. Stage ALL files together
9. Commit with descriptive message

# WRONG - never do this:
git add src/
git commit -m "implement feature"
# Documentation left for "later" = documentation never happens
```

## Plans Must Be Persisted

If you create a plan during this session (via EnterPlanMode or research):

1. Write it to `notes/plans/YYYY-MM-DD-topic-kebab-case.md`
2. Create a handoff in `notes/handoffs/` referencing the plan
3. Include both in your commit

Plans in the context window are lost on session end. Plans on disk survive.

## Human Testing Plans

When a task requires verification outside the sandbox (real sessions, live hooks,
subjective quality assessment), do not leave a vague "human must test" note. Instead:

1. Create a test plan at `notes/plans/YYYY-MM-DD-phase-N-topic.md`
2. Structure it so an LLM agent can read it and drive each step interactively with a human
3. Each step: what to run, expected output, PASS/FAIL criteria
4. Include an Agent Protocol section (step ordering, result tracking, failure handling)
5. Map steps to WORKPLAN gates so the agent knows what to check off on completion
6. Reference the plan from the WORKPLAN phase and handoff notes

See existing plans in `notes/plans/` for examples.

## Proposals

When writing a proposal (design decision, refactor rationale, approach comparison):

1. Follow the template at `notes/proposals/TEMPLATE.md`
2. Save as `notes/proposals/YYYY-MM-DD-topic-kebab-case.md`
3. Every Evolution Path item MUST be registered as a review gate in WORKPLAN.md
4. At the start of each phase, check the "Review gates" section — if a trigger condition
   is met, read the referenced proposal and re-evaluate before proceeding

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
