# Claude Conversation Sync Workplan

**Target**: Cross-session context awareness for Claude Code via event extraction and status synthesis.
**Status**: Infrastructure complete. Ready for Phase 1 (Capture).

## Critical Rules

1. **Gate integrity.** Never check off a gate item until verified. Gates are non-negotiable.
2. **Small, frequent commits.** Each commit includes corresponding doc updates.
3. **Research before implementation.** Each phase begins with research committed to `notes/`.
4. **Update WORKPLAN.md before exiting.** Phase index, progress checkboxes. Handoff details go in `notes/handoffs/`.
5. **Append to progress.log.** Timestamped single-line entries for monitoring.

## Operational Notes

- Build: `nix develop --impure` then `cabal build`
- Test: `cabal test`
- Run: `cabal run ccs -- --help`
- Git: Follow 50/72 commit message rule, focus on why

## Phase Index

| Phase | Description | Status | Blocked By |
|-------|-------------|--------|------------|
| Infra.1-3 | flake.nix, Haskell skeleton, beads | **DONE** | — |
| Infra.4 | MicroVM sandboxing for ralph loops | **ABANDONED** | Infra.1-3 |
| 0 | Spike: validate extraction approach | PARTIAL | — |
| 1 | Capture: hooks + signals | **DONE** | — |
| 2a | Tooling: pre-filter, record-event, aggregation | **DONE** | Infra, Phase 1 (signal format) |
| 2b | Prompts: extraction, handoff, progress, synthesis | **DONE** | Infra |
| 2c | Integration: wire everything together | **DONE** (2c.2 verified 2026-03-08, code fence stripping TODO) | 1, 2a, 2b |
| 3 | Status & Handoffs: generate outputs | **CODE COMPLETE** (3.4 awaits human quality validation) | 2c |
| 4 | Retrieval: context injection (optional) | DEFERRED | 3 |
| 5 | Archival: manage EVENTS.jsonl growth | DEFERRED | 4 |
| S.PS | Project Status Sync: periodic service module | IN PROGRESS (S.PS.1-3 done) | S.PS.5 quality portion blocked by 3.4, S.PS.6 unblocked |

## Phase Diagram

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
│ Project ID logic│ record-event CLI│ Handoff prompt    │       │
│ Signal format   │ Aggregation job │ Progress prompt   │       │
│                 │   skeleton      │ Synthesis prompt  │       │
└────────┬────────┴────────┬────────┴─────────┬─────────┘       │
         │                 │                  │                 │
         └────────────────►├◄─────────────────┘                 │
                           │                                    │
                    Integration (Phase 2c)                      │
                           │                                    │
                           ▼                                    │
                    Phase 3: Status & Handoffs                  │
                           │                                    │
                           ├──► S.PS: Project Status Sync       │
                           │    (systemd/launchd service)       │
                           ▼                                    │
                    Phase 4: Retrieval (deferred)               │
                           │                                    │
                           ▼                                    │
                    Phase 5: Archival (deferred)                │
                                                                │
◄───────────────────── Validation gates ────────────────────────┘
```

---

## Phase Infra: Project Infrastructure

**Goal**: Establish build system and project skeleton before implementation.

### Gates

- [x] `nix develop` enters shell with GHC, cabal, HLS
- [x] `cabal build` compiles empty executable
- [x] `cabal test` runs (even if no tests yet)
- [x] beads initialized at `beads/.beads/`

### Chunks

#### Infra.1: flake.nix with nixDir

- Create `flake.nix` with nixpkgs input
- Create `nix/packages/ccs/default.nix` (Haskell derivation)
- Create `nix/devenvs/default.nix` (dev shell)
- Verify: `nix develop` works

#### Infra.2: Haskell skeleton

- Create `ccs.cabal` with library + executable
- Create `src/CCS.hs` (library entry point)
- Create `app/Main.hs` (CLI entry point)
- Create `test/Main.hs` (test entry point)
- Verify: `cabal build && cabal test` works

#### Infra.3: beads initialization

- Create `beads/.beads/` directory
- Run `bd init`
- Create initial tickets from this workplan

### Progress

- [x] Infra.1: flake.nix with nixDir
- [x] Infra.2: Haskell skeleton
- [x] Infra.3: beads initialization

See: `notes/handoffs/2026-03-02-infra-project-bootstrap.md`

---

## Phase Infra.4: MicroVM Sandboxing

**Status**: ABANDONED (2026-03-03) → replaced by bubblewrap sandbox (2026-03-05)

**Goal**: Enable safe ralph loops by running Claude in ephemeral NixOS VMs.

**Why abandoned**: Fundamental issues with sharing /nix/store made it impractical:
- 9p too slow for nix store access patterns
- virtiofs required complex host daemon setup
- nix database not shared, causing redundant fetches
- Read-only squashfs root conflicted with writable store needs

**Bubblewrap replacement**: Custom `claude-headless-ccs` built inline in devenv using
`bubblewrap-claude.lib.deriveProfile`. Includes all dev tools (ghc, cabal, HLS, fourmolu,
hlint, nixfmt) so `cabal test` works inside the sandbox. Devenv is the single source of truth
for the tool list.

### Gates (historical)

- [x] VM boots successfully: `./scripts/run-sandbox.sh`
- [x] Cannot access host `~/.ssh` from inside VM (not mounted)
- [x] Can read/write `/project` (shared project directory)
- [ ] API calls succeed (anthropic credentials work) — not tested
- [ ] ralph-loop-sandboxed.sh runs one session cycle — not tested

### Chunks

#### Infra.4.1: Add microvm.nix to flake

- Add microvm.nix input ✓
- Import nixosModules.microvm ✓
- Export claude-sandbox package ✓

#### Infra.4.2: Define claude-sandbox VM

- Create `nix/microvm/claude-sandbox.nix` ✓
- Configure 4 vCPU, 4GB RAM ✓
- 9p shares for nix store, gitconfig, anthropic ✓
- User networking ✓
- Dynamic project share via extraArgsScript ✓

#### Infra.4.3: Create ralph-loop-sandboxed.sh

- Create `scripts/ralph-loop-sandboxed.sh` ✓
- Prompt writing to .ralph-prompt ✓
- Dynamic 9p share arguments ✓
- Exit code handling ✓
- Stop file support ✓

#### Infra.4.4: Supporting files

- Create `RALPH.md` ✓
- Create `.msgs/` directory ✓

#### Infra.4.5: Verification

- [ ] Test VM boot
- [ ] Test isolation (cannot access ~/.ssh)
- [ ] Test project share (can read/write /project)
- [ ] Test API key (claude can authenticate)

### Progress

- [x] Infra.4.1: Add microvm.nix to flake
- [x] Infra.4.2: Define claude-sandbox VM
- [x] Infra.4.3: Create ralph-loop-sandboxed.sh
- [x] Infra.4.4: Supporting files
- [x] Infra.4.5: Verification (partial — VM boots, project mounts, isolation works)

See:
- `notes/handoffs/2026-03-03-microvm-abandoned.md`
- `notes/handoffs/2026-03-03-microvm-nix-store-caching.md`
- `notes/handoffs/2026-03-03-nixdir-configuration-fix.md`
- `notes/handoffs/2026-03-04-ralph-scripts-audit.md`

---

## Phase 0: Spike

**Goal**: Validate the extraction approach before building infrastructure.

### Gates

- [ ] Pre-filter script tested on 3+ real sessions
- [ ] Extraction prompt produces useful events
- [ ] Events still useful 2 weeks later (validate over time)

### Chunks

#### 0.1: Pre-filter validation

- Run `scripts/jsonl-to-summary-input.sh` on real session files
- Verify output is clean plain text with USER/ASSISTANT labels
- Document any edge cases or failures

#### 0.2: Extraction prompt testing

- Run extraction prompt via `claude -p` on pre-filtered sessions
- Inspect extracted events for signal-to-noise
- Iterate prompt if too noisy or missing important events

#### 0.3: Temporal validation

- Wait 2 weeks, revisit extracted events
- Are they useful for understanding what happened?
- If not, iterate prompt and re-extract

### Progress

- [x] 0.1: Pre-filter script exists and tested (99% size reduction)
- [x] 0.2: Extraction prompt exists at `prompts/session-extraction.md`
- [ ] 0.3: Temporal validation (need to wait and revisit)

See: `notes/handoffs/2026-03-01-spike-initial-artifacts.md`

---

## Phase 1: Capture

**Goal**: Reliably capture session artifacts when sessions end.

### Gates

- [ ] SessionEnd hook writes `.available` signal with transcript path and cwd
- [ ] Project identification works for git repos, monorepos, non-git dirs
- [ ] 5 real sessions captured successfully

### Chunks

#### 1.1: Signal format definition

- Define `.available` file JSON schema: `{"transcript_path": "...", "cwd": "..."}`
- Document in `docs/design.md` (already done)
- Create example signal file

#### 1.2: Project identification module

- Implement `CCS.Project` module
- Git remote + subpath → ProjectKey
- Directory fallback for non-git projects

#### 1.3: SessionEnd hook

- Create hook script (reads JSON from stdin)
- Write `.available` signal file

#### 1.4: Hook registration via home-manager module

**Approach**: Follow the beads pattern — standalone package + home-manager module that
contributes to `programs.claude-code.settings.hooks`.

**1.4a: Package the hook script** (`nix/packages/ccs-session-end-hook/default.nix`)

- Use `pkgs.writeShellApplication` to create a derivation
- Name: `ccs-session-end-hook`
- Runtime deps: `jq` (the only external dependency)
- Move `scripts/session-end-hook.sh` logic into the package derivation
- The packaged script gets `jq` on PATH automatically via `writeShellApplication`
- Exported as `packages.<system>.ccs-session-end-hook` via nixDir auto-discovery

**1.4b: Home-manager module** (`nix/modules/home-manager/ccs-session-end-hook/default.nix`)

- Option namespace: `programs.claude-code.plugins.conversation-sync`
- `enable` option via `lib.mkEnableOption`
- `package` option defaulting to `inputs.self.packages.${system}.ccs-session-end-hook`
- Optional `signalDir` option (overrides `CCS_SIGNAL_DIR`, defaults to XDG)
- Sets `programs.claude-code.settings.hooks.SessionEnd` with command pointing to
  `${cfg.package}/bin/ccs-session-end-hook`
- If `signalDir` is set, wraps the command with `CCS_SIGNAL_DIR=... ` prefix
- Exported as `homeManagerModules.ccs-session-end-hook` via nixDir

**1.4c: Verification**

- `nix build .#ccs-session-end-hook` succeeds
- Built script has `jq` on PATH (check via `ldd` or running it)
- Manual test: `echo '{"session_id":"test","transcript_path":"/tmp/t","cwd":"/tmp"}' | ccs-session-end-hook`
  creates signal file
- After importing in a consuming flake: `~/.claude/settings.json` contains `SessionEnd`
  hook entry pointing to `/nix/store/.../bin/ccs-session-end-hook`

### Progress

- [x] 1.1: Signal format definition
- [x] 1.2: Project identification module
- [x] 1.3: SessionEnd hook
- [x] 1.4: Hook registration (1.4a + 1.4b done, 1.4c needs nix build verification)

See:
- `notes/handoffs/2026-03-05-signal-format-and-project-id.md` (1.1, 1.2)
- `notes/handoffs/2026-03-05-session-end-hook.md` (1.3)
- `notes/handoffs/2026-03-05-hook-registration-packaging.md` (1.4a+b)
- `notes/handoffs/2026-03-04-phase-1.4-spec.md` (1.4 spec)

---

## Phase 2a: Tooling

**Goal**: Build processing infrastructure.

### Gates

- [ ] `ccs filter` converts JSONL → plain text
- [ ] `record-event` CLI appends to EVENTS.jsonl
- [ ] Aggregation job skeleton handles quiet period + locking

### Chunks

#### 2a.1: Pre-filter as library function

- Port `scripts/jsonl-to-summary-input.sh` to Haskell
- Create `CCS.Filter` module
- Parse JSONL, extract user/assistant text and thinking blocks
- Output plain text with role labels (THINKING: for reasoning)

#### 2a.2: CLI scaffolding

- Set up optparse-applicative
- `ccs filter <input>` subcommand
- `ccs aggregate` subcommand (skeleton)

#### 2a.3: record-event tool

- Create `record-event` CLI (separate executable or subcommand)
- `--tag`, `--text`, `--source` arguments
- Append JSON line to `$SESSION_EVENTS_FILE`
- Used by LLM subprocess during extraction

#### 2a.4: Aggregation job skeleton

- Watch for `.available` signals
- Quiet period logic (wait N minutes after last signal)
- File locking for concurrent safety
- Signal consumption (delete after processing)

### Progress

- [x] 2a.1: Pre-filter as library function
- [x] 2a.2: CLI scaffolding
- [x] 2a.3: record-event tool
- [x] 2a.4: Aggregation job skeleton (build verified, RIO compat fixes applied)

See:
- `notes/handoffs/2026-03-06-pre-filter-library.md`
- `notes/handoffs/2026-03-06-filter-thinking-blocks.md`
- `notes/handoffs/2026-03-06-codify-review-learnings.md`
- `notes/handoffs/2026-03-06-cli-scaffolding.md`
- `notes/handoffs/2026-03-06-record-event-tool.md`
- `notes/handoffs/2026-03-06-aggregation-skeleton.md`

---

## Phase 2b: Prompts

**Goal**: Design and test all LLM prompts.

### Gates

- [ ] Extraction prompt refined based on Phase 0 learnings
- [ ] Synthesis prompt produces useful STATUS.md
- [ ] Handoff generation prompt creates useful session summaries
- [ ] Progress entry prompt produces well-formatted log entries

### Chunks

#### 2b.1: Extraction prompt refinement

- Review Phase 0 results
- Adjust tag vocabulary if needed
- Improve signal-to-noise ratio
- Document prompt design decisions

#### 2b.2: Synthesis prompt

- Create `prompts/status-synthesis.md`
- Input: EVENTS.jsonl + list of recent handoff files
- Output: STATUS.md in 4-question format with handoff wikilinks
- Test with sample events

#### 2b.3: Handoff generation prompt

- Create `prompts/handoff-generation.md`
- Input: this session's events
- Output: handoff markdown + topic slug for filename
- Target 50-150 words

#### 2b.4: Progress entry prompt

- Create `prompts/progress-entry.md`
- Input: session events
- Output: single-line progress.log entry
- Format: `{date} {time} [{session}] — {summary}`

### Progress

- [x] Extraction prompt exists (needs refinement in 2b.1)
- [x] 2b.1: Extraction prompt refinement
- [x] 2b.2: Synthesis prompt (`prompts/status-synthesis.md`)
- [x] 2b.3: Handoff generation prompt (`prompts/handoff-generation.md`)
- [x] 2b.4: Progress entry prompt (`prompts/progress-entry.md`)

See:
- `notes/handoffs/2026-03-03-prompts-and-commit-discipline.md`
- `notes/handoffs/2026-03-08-extraction-prompt-refinement.md`

---

## Phase 2c: Integration

**Goal**: Wire together capture, tooling, and prompts.

### Gates

- [x] End-to-end: session ends → EVENTS.jsonl updated (verified 2026-03-08)
- [x] Aggregation job invokes extraction prompt correctly (verified 2026-03-08)
- [ ] ~~record-event subprocess pattern works~~ (replaced by stdout parsing — see 2c.1 handoff)

### Chunks

#### 2c.1: Aggregation job completion

- Wire quiet period trigger to processing
- For each pending signal:
  - Read session JSONL from `transcript_path`
  - Run pre-filter
  - Invoke `claude -p` with extraction prompt
  - Collect events from record-event output
  - Append to EVENTS.jsonl

#### 2c.2: End-to-end testing

- Run real session
- Verify hook fires
- Verify aggregation processes after quiet period
- Inspect EVENTS.jsonl for correctness

### Progress

- [x] 2c.1: Aggregation job completion
- [x] 2c.2: End-to-end testing (human-verified 2026-03-08, steps 1-5 PASS)

**2c.2 test results** (2026-03-08):

Steps 1-5 of `notes/plans/2026-03-08-phase-2c2-pipeline-verification.md` all PASS.
Step 6 (live hook integration) skipped — not required for gate.

| Step | Result | Notes |
|------|--------|-------|
| 1 — Hook smoke test | PASS | Signal file created with correct content |
| 2 — Filter real transcript | PASS | Clean USER:/ASSISTANT:/THINKING: labels |
| 3 — Signal discovery | PASS | "Processing 1 signal(s)", expected failure on fake path |
| 4 — Full pipeline | PASS | All 4 outputs exist with reasonable content |
| 5 — Signal consumption | PASS | Signal directory empty after processing |
| 6 — Live hook | SKIP | Not required for gate |

**Issues found during 2c.2 testing**:
- [x] `CLAUDECODE` env var prevents `claude -p` subprocess — `--bypass-claude-check` flag added to `ccs aggregate`
- [x] LLM wraps STATUS.md and progress.log output in code fences (` ```markdown ` / ` ``` `) — `stripCodeFences` applied in `runLLMPrompt` (all outputs cleaned centrally)

**Pending refactors** (from process review):
- [x] Extract `AggregateConfig` record from `AggregateCmd` (6 positional fields → named record)
- [x] Proposal: `Maybe FilePath` in `ProcessConfig` → See `notes/proposals/2026-03-08-process-config-prompt-fields.md` (Option B: APPROVED)
- [x] Implement proposal: remove Maybe from prompt fields, make CLI flags required
- [x] Update `docs/design.md` to reflect stdout-parsing approach (currently documents record-event subprocess)

**Review gates** (assessed 2026-03-08 after Phase 3.3 landed):
- [x] PromptBundle (Option C): **Not yet.** 4 prompt fields in 7-field named records is manageable. `AggregateConfig` extraction resolved the positional-fields pain. Reassess if a 5th prompt is added.
- [x] Extraction-only (`ccs extract`): **No need.** Pipeline always runs all 4 stages; no use case for extraction-only has surfaced. Revisit only if a concrete need arises.

See:
- `notes/handoffs/2026-03-08-aggregation-pipeline-wiring.md`
- `notes/handoffs/2026-03-08-review-gate-assessment.md`

---

## Phase 3: Status & Handoffs

**Goal**: Generate useful STATUS.md, handoffs, and progress.log from accumulated events.

### Gates

- [ ] STATUS.md generated at end of aggregation run with handoff wikilinks
- [ ] Handoff files generated per session in `handoffs/` directory
- [ ] progress.log accumulates entries correctly
- [ ] Reading STATUS.md cold provides project understanding

### Chunks

#### 3.1: Processing flow integration

Wire all prompts to aggregation job in order:
1. Run extraction → append to EVENTS.jsonl
2. Run handoff generation → write `handoffs/{date}-{session}-{topic}.md`
3. Append progress.log entry
4. Run synthesis → write STATUS.md (last, so it can link to new handoff)

#### 3.2: Handoff output

- Write to `{project}/handoffs/{date}-{sessionID}-{topic}.md`
- Topic derived by LLM from session events
- Target 50-150 words

#### 3.3: STATUS.md output

- Write to `{project}/STATUS.md`
- Overwrite on each run (not append)
- Include Recent Handoffs section with Obsidian wikilinks

#### 3.4: Quality validation

- Generate outputs for this project
- Read STATUS.md cold after 1 week
- Does it help understand where we are?
- Do handoff links work in Obsidian?

### Progress

- [x] 3.1: Processing flow integration (handoff + progress wired; synthesis deferred to 3.3)
- [x] 3.2: Handoff output (writes to `{project}/handoffs/{date}-{prefix}-{topic}.md`)
- [x] 3.3: STATUS.md output (synthesis prompt wired into processSession, writes `{project}/STATUS.md`)
- [ ] 3.4: Quality validation (requires real pipeline run + cold read after 1 week — human-verified)

See:
- `notes/handoffs/2026-03-08-processing-flow-integration.md`
- `notes/handoffs/2026-03-08-status-synthesis-wiring.md`

---

## Phase 4: Retrieval (Deferred)

**Goal**: Surface context at session start.

**MVP approach**: Working agent reads STATUS.md and handoffs via CLAUDE.md instructions.
No automatic hooks or slash commands needed for MVP.

### Gates

- [ ] CLAUDE.md template documented for context injection
- [ ] (Optional) UserPromptSubmit hook detects STATUS.md
- [ ] (Optional) `/context` command works with filters

### Chunks

#### 4.1: CLAUDE.md template

- Document pattern for referencing STATUS.md and handoffs
- Example snippet for project CLAUDE.md files

#### 4.2: UserPromptSubmit hook (optional)

- Detect project from CWD
- Check if STATUS.md exists
- Show offer with metadata (last updated, event count)
- User confirms before loading

#### 4.3: /context slash command (optional)

- Create skill for `/context`
- Default: STATUS.md + last 3-5 sessions
- Flags: `--last N`, `--since DATE`, `--tag TAG`, `--deep`

### Progress

- [ ] 4.1: CLAUDE.md template
- [ ] 4.2: UserPromptSubmit hook (optional)
- [ ] 4.3: /context slash command (optional)

---

## Phase 5: Archival (Deferred)

**Goal**: Manage EVENTS.jsonl growth over time.

### Gates

- [ ] Monthly archival moves old events to archive files
- [ ] Archive Entry pointers left in main EVENTS.jsonl
- [ ] `--deep` flag searches archive files

### Chunks

*(To be defined when phase is activated)*

### Progress

*(Deferred)*

---

## Supplementary: Haskell Development Skill

**Goal**: Codify Haskell development conventions for coding agents.

### Implementation

- Skill content at `nix/packages/haskell-development-skill/` (SKILL.md + references/)
- Package derivation builds to `share/claude/skills/haskell-development-skill/`
- Home-manager module at `nix/modules/home-manager/haskell-development-skill/`
- Devenv module at `nix/modules/devenv/haskell-development-skill.nix` (fourmolu + hlint + git-hooks)
- Exported as `packages.<system>.haskell-development-skill` and `homeManagerModules.haskell-development-skill`

### Conventions Covered

RIO-based: NoImplicitPrelude, ReaderT pattern, Has* typeclasses with lenses,
strict fields, no partial functions, Maybe/Either for detectable errors,
Text over String, structured logging, MonadUnliftIO, point-free style,
let-in over where.

### Testing Conventions

Tasty + tasty-hunit + tasty-quickcheck. Property tests for pure functions
with clear invariants (idempotence, format-independence, round-trips).
Targeted generators over arbitrary ones to exercise real code paths.

### Tooling

- Fourmolu (formatter) — git pre-commit hook
- HLint (linter) — git pre-commit hook
- cabal-test — git pre-commit hook (devenv module at `nix/modules/devenv/cabal-test.nix`)

See:
- `notes/handoffs/2026-03-04-haskell-development-skill.md`
- `notes/handoffs/2026-03-04-rio-refactor.md`

---

## Supplementary: Session Tracking

**Goal**: Enable tracing progress.log entries back to conversation transcripts.

### Implementation

- Devenv module at `nix/modules/devenv/session-tracking.nix`
- Exported as `devenvModules.session-tracking`
- `UserPromptSubmit` hook writes session ID to `.current-session-id`
- Agents include session prefix in progress.log entries
- Format: `YYYY-MM-DD HH:MM [<8-char-prefix>] — Phase X.Y: description`

See: `notes/handoffs/2026-03-03-session-tracking.md`

---

## Supplementary: Ralph Loop Protocol

**Goal**: Role-aware headless sessions that triage work before executing.

### Implementation

- Protocol defined in `RALPH.md`
- Triage step spawns `product-owner` agent to determine session role
- Four roles: PM, Architect, Implementer, Reviewer
- Decision protocol elevates domain decisions to proposals instead of inline execution

### Key Rules

- Domain decisions (Maybe in ADTs, >3 positional fields, pattern changes) → proposal, not implementation
- PM role prioritized when WORKPLAN is stale
- Only Implementer role loads haskell-development-skill and touches `src/`

See: `notes/handoffs/2026-03-08-ralph-role-protocol.md`

---

## Supplementary: Project Status Sync Service

**Goal**: Unified home-manager module that captures session signals (SessionEnd hook) AND
runs periodic aggregation (systemd timer / launchd agent). Replaces the standalone
`ccs-session-end-hook` module.

### Design Decisions

- **Merged module**: `programs.project-status-sync` handles both capture and processing.
  Enabling it registers the SessionEnd hook into Claude Code AND sets up the timer service.
- **Periodic timer, not daemon**: systemd timer (Linux) / launchd StartInterval (macOS)
  invokes `ccs aggregate` every 5 minutes. Quiet period check already built into CLI.
- **Configurable LLM command**: `--llm-command` / `--llm-arg` CLI flags allow using
  `airchat claude -- -p` at work instead of the default `claude -p`.
- **Prompts embedded in binary**: Prompts compiled into the ccs binary via `file-embed`.
  No runtime prompt directory needed. Individual `--*-prompt FILE` flags remain as optional
  overrides for development iteration.
- **`--bypass-claude-check` not needed**: The service runs outside Claude Code, so the
  CLAUDECODE env var check is irrelevant. Module does not pass or expose this flag.
- **Hook composability**: Use `lib.mkAfter` when setting `hooks.SessionEnd` so other modules
  can also register SessionEnd hooks without conflicts.
- **Failures are silent**: If `ccs aggregate` fails, the timer re-fires in 5 minutes. No
  alerting mechanism. Future work may add `OnFailure=` notification.

### Chunks

#### S.PS.1: CLI changes

- Add `--llm-command CMD` flag to `ccs aggregate` (default: `claude`)
- Add `--llm-arg ARG` repeatable flag (default when none given: `-p`).
  Example: `--llm-command airchat --llm-arg claude --llm-arg -- --llm-arg -p`
- Embed prompts in binary via `file-embed` — zero-config default
- Keep individual `--*-prompt FILE` flags as optional overrides for development
- ProcessConfig prompt fields changed from `FilePath` to `Text` (prompt content)
- Files: `app/Main.hs`, `app/Prompts.hs`, `src/CCS/Process.hs`, `ccs.cabal`,
  `nix/packages/ccs/default.nix`, `nix/modules/home-manager/project-status-sync/`

#### S.PS.2: project-status-sync home-manager module (NEXT — unblocked)

- Create `nix/modules/home-manager/project-status-sync/default.nix`
- Registers SessionEnd hook (via `lib.mkAfter`) + sets up periodic timer service
- Asserts `programs.claude-code.enable` with readable error message
- Platform-conditional: systemd on Linux, launchd on macOS
- Auto-discovered by nixDir as `homeManagerModules.project-status-sync`

Module options (`programs.project-status-sync`):

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | bool | false | Enable capture hook + periodic aggregation |
| `package` | package | `ccs` | Binary providing `ccs aggregate` (prompts embedded) |
| `signalDir` | str | `${xdg.stateHome}/ccs/signals` | Signal directory (shared by hook and service) |
| `outputDir` | str | **(required)** | Output for EVENTS.jsonl, STATUS.md, handoffs |
| `quietPeriodMinutes` | int | 20 | Quiet period before processing |
| `intervalMinutes` | int | 5 | Timer frequency |
| `llmCommand` | str | `"claude"` | LLM binary (e.g. `"airchat"`) |
| `llmArgs` | listOf str | `["-p"]` | Args for LLM command (e.g. `["claude" "--" "-p"]`) |
| `orgMappings` | attrsOf str | `{}` | Map git host/org → human name (see S.PS.6) |
| `projectOverrides` | attrsOf str | `{}` | Override project output paths (see S.PS.6) |

#### S.PS.3: Deprecate ccs-session-end-hook module

- Mark existing module as deprecated
- Migration: `programs.claude-code.plugins.conversation-sync` → `programs.project-status-sync`

#### S.PS.4: Integration in zoo.nix

- Replace `homeManagerModules.ccs-session-end-hook` with `homeManagerModules.project-status-sync`
- Configure `programs.project-status-sync` with `outputDir`
- `home-manager switch` activates both hook and timer

#### S.PS.5: Verification (mechanical items unblocked; quality judgment blocked by 3.4)

- SessionEnd hook fires and writes `.available` signal
- Timer fires on schedule (`systemctl --user list-timers`)
- `ccs aggregate` runs and produces output
- LLM subprocess finds `claude`/`airchat` on PATH
- Lock file prevents concurrent runs
- Quality of LLM outputs (STATUS.md, handoffs) — blocked by 3.4 cold read

#### S.PS.6: orgMappings and projectOverrides (unblocked — independent of S.PS.4/5)

**Goal**: Control how project keys map to output directory paths. Currently `processSession`
uses `projectDir = pcOutputDir </> T.unpack pname` where `pname` is just the last path
component (e.g., `ergo`). This is insufficient for multi-org setups where projects from
different orgs would collide or lack organizational context.

**orgMappings** — map git host/org prefixes to human-readable names for output path derivation:
- Input: project key `git.musta.ch/airbnb/ergo`, mapping `git.musta.ch/airbnb → Airbnb`
- Output path: `{outputDir}/Airbnb/ergo/`
- Without mapping: `{outputDir}/ergo/` (current behavior, last path component only)
- Longest prefix match wins when multiple mappings overlap

**projectOverrides** — override the entire output subpath for a specific project key:
- Input: project key `git.musta.ch/airbnb/legacy`, override `→ Airbnb/archived/legacy`
- Output path: `{outputDir}/Airbnb/archived/legacy/`
- Checked before orgMappings — exact match on project key takes priority

**S.PS.6a: Library — output path derivation with mappings**

- New type in `CCS.Project`: `OrgMappings` (newtype over `Map Text Text`)
- New type in `CCS.Project`: `ProjectOverrides` (newtype over `Map Text Text`)
- New function `deriveOutputSubpath :: ProjectKey -> OrgMappings -> ProjectOverrides -> FilePath`
  - Check projectOverrides first (exact match on key)
  - Then check orgMappings (longest prefix match, replace prefix with mapped name)
  - Fallback: current `deriveName` behavior (last path component)
- Tests: prefix matching, override priority, fallback, overlapping prefixes
- Files: `src/CCS/Project.hs`, `test/`

**S.PS.6b: CLI — new flags**

- Add `--org-mapping KEY=VALUE` repeatable flag to `ccs aggregate`
  - Parsed as `Text` split on first `=`
  - Example: `--org-mapping "git.musta.ch/airbnb=Airbnb"`
- Add `--project-override KEY=PATH` repeatable flag to `ccs aggregate`
  - Same parsing
  - Example: `--project-override "git.musta.ch/airbnb/legacy=Airbnb/archived/legacy"`
- Add `acOrgMappings` and `acProjectOverrides` to `AggregateConfig`
- Thread through to `ProcessConfig` and into `processSession`
- Files: `app/Main.hs`, `src/CCS/Process.hs`

**S.PS.6c: Nix module — wire options to CLI flags**

- Update `aggregateCommand` in `project-status-sync/default.nix` to pass
  `--org-mapping` and `--project-override` flags from module options
- Remove "blocked on CLI" notes from module options table
- Files: `nix/modules/home-manager/project-status-sync/default.nix`

### Gates

- [x] `--llm-command` / `--llm-arg` flags work (`cabal test` — 79 tests pass)
- [x] Prompts embedded in binary via `file-embed` — no runtime directory needed
- [ ] Module evaluates on both Linux and macOS
- [ ] SessionEnd hook registers correctly (composable via `mkAfter`)
- [ ] Timer activates after `home-manager switch`
- [ ] End-to-end: session end → signal → timer fires → outputs generated
- [ ] `--org-mapping` flag correctly maps host/org prefix to output subpath
- [ ] `--project-override` flag overrides output subpath for exact project key match
- [ ] Nix module wires `orgMappings` and `projectOverrides` to CLI flags

### Progress

- [x] S.PS.1: CLI changes (--llm-command, --llm-arg, embedded prompts via file-embed)
- [x] S.PS.2: project-status-sync home-manager module
- [x] S.PS.3: Deprecate ccs-session-end-hook module
- [ ] S.PS.4: Integration in zoo.nix
- [ ] S.PS.5: Verification
- [x] S.PS.6a: Library — output path derivation with OrgMappings, ProjectOverrides, deriveOutputSubpath
- [x] S.PS.6b: CLI — --org-mapping and --project-override flags
- [ ] S.PS.6c: Nix module — wire orgMappings/projectOverrides options to CLI flags

**Runtime dependency** (2026-03-09): S.PS.2 module passes `--llm-command`
and `--llm-arg` flags to `ccs aggregate`. Prompts are embedded in the binary — no
`--prompts-dir` flag needed. S.PS.1 is now complete.

**Blocker reconciliation** (2026-03-09): S.PS.2-4 were previously listed as blocked by 3.4
(quality validation). This was overly conservative. 3.4 tests whether LLM-generated output
is subjectively useful — it says nothing about the Nix module that wraps the CLI, the
deprecation of the old module, or the zoo.nix integration. S.PS.2-4 are pure infrastructure
and unblocked from 3.4. Only S.PS.5's quality judgment depends on 3.4.

**Sandbox constraint** (2026-03-11): S.PS.4 modifies `~/Projects/self/zoo.nix` and S.PS.5
requires `home-manager switch` + systemd/launchd verification. Neither is doable from
the bubblewrap sandbox (only `/home/roman/project` is writable). These must be done in an
interactive session with full filesystem access.

See:
- `notes/handoffs/2026-03-09-pm-blocker-reconciliation.md`
- `notes/handoffs/2026-03-09-sps2-home-manager-module.md`
- `notes/handoffs/2026-03-09-sps1-cli-flags.md`
- `notes/handoffs/2026-03-11-sps6a-output-path-derivation.md`
- `notes/handoffs/2026-03-11-sps6b-cli-mapping-flags.md`
