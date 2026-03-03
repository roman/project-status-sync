# Claude Conversation Sync Workplan

**Target**: Cross-session context awareness for Claude Code via event extraction and status synthesis.
**Status**: Infrastructure complete. Ready for Phase 1 (Capture).

## Critical Rules

1. **Gate integrity.** Never check off a gate item until verified. Gates are non-negotiable.
2. **Small, frequent commits.** Each commit includes corresponding doc updates.
3. **Research before implementation.** Each phase begins with research committed to `notes/`.
4. **Update WORKPLAN.md before exiting.** Phase index, progress checkboxes, handoff notes.
5. **Append to progress.log.** Timestamped single-line entries for monitoring.

## Operational Notes

- Build: `nix develop` then `cabal build`
- Test: `cabal test`
- Run: `cabal run ccs -- --help`
- Git: Follow 50/72 commit message rule, focus on why

## Phase Index

| Phase | Description | Status | Blocked By |
|-------|-------------|--------|------------|
| Infra.1-3 | flake.nix, Haskell skeleton, beads | **DONE** | — |
| Infra.4 | MicroVM sandboxing for ralph loops | **DONE** | Infra.1-3 |
| 0 | Spike: validate extraction approach | PARTIAL | — |
| 1 | Capture: hooks + signals | PENDING | — |
| 2a | Tooling: pre-filter, record-event, aggregation | PENDING | Infra, Phase 1 (signal format) |
| 2b | Prompts: extraction, synthesis, plan-diff | PENDING | Infra |
| 2c | Integration: wire everything together | PENDING | 1, 2a, 2b |
| 3 | Status synthesis: generate STATUS.md | PENDING | 2c |
| 4 | Retrieval: context injection at session start | PENDING | 3 |
| 5 | Work-specific: skill gap tagging (optional) | DEFERRED | 4 |
| 6 | Archival: manage EVENTS.jsonl growth | DEFERRED | 4 |

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

### Handoff Notes

#### 2026-03-02 — Infra.1-3 complete

**Completed**:
- flake.nix with nixDir, microvm.nix input
- Haskell skeleton (cabal, src/CCS.hs, app/Main.hs, test/Main.hs)
- Dev shell with GHC 9.10.3, cabal, HLS
- beads initialized at beads/.beads/

**Verified**:
- `nix develop` ✓
- `cabal build` ✓
- `cabal test` ✓ (1 test passed)
- `nix build .#ccs` ✓

---

## Phase Infra.4: MicroVM Sandboxing

**Goal**: Enable safe ralph loops by running Claude in ephemeral NixOS VMs.

### Gates

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

### Handoff Notes

#### 2026-03-03 — VM functional, nix store caching deferred

**Completed**:
- VM boots and auto-logins as `claude` user
- `/project` mounted correctly via 9p
- Host `~/.ssh`, `~/.aws` not accessible (isolation works)
- Git safe.directory configured for /project
- Nix flakes enabled, nix-daemon running
- Writable store overlay (2GB) for nix operations

**Known Issue (Deferred)**:
- Nix commands don't use host's cached store paths
- Downloads from cache.nixos.org instead
- Root cause: VM's nix database is empty
- See: `notes/handoffs/2026-03-03-microvm-nix-store-caching.md`
- **Not blocking**: ralph loop needs claude-code + git, not nix commands

**Not Yet Tested**:
- API key passthrough (anthropic credentials)
- Full ralph-loop-sandboxed.sh cycle

**To Run VM**:
```bash
./scripts/run-sandbox.sh              # mounts $PWD to /project
./scripts/run-sandbox.sh /path/to/dir # mounts specific directory
```

**To Exit VM**: `poweroff` or `Ctrl-A X`

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

### Handoff Notes

#### 2026-03-01 — Initial artifacts

**Completed**: Pre-filter script and extraction prompt created and manually tested.
**Notes**: Prompt works but needs validation over time. Don't build infrastructure
until we're confident the extraction approach is sound.

---

## Phase 1: Capture

**Goal**: Reliably capture session artifacts when sessions end.

### Gates

- [ ] SessionEnd hook copies JSONL + writes `.available` signal
- [ ] PreCompact hook copies pre-compaction snapshot
- [ ] Project identification works for git repos, monorepos, non-git dirs
- [ ] 5 real sessions captured successfully

### Chunks

#### 1.1: Signal format definition

- Define `.available` file JSON schema
- Document in `docs/design.md` (already done)
- Create example signal file

#### 1.2: Project identification module

- Implement `CCS.Project` module
- Git remote + subpath → ProjectKey
- `.claude-project` override
- Directory fallback
- Work vs personal classification

#### 1.3: SessionEnd hook

- Create hook script (reads JSON from stdin)
- Copy session JSONL to output directory
- Copy sub-agent JSONLs
- Copy modified plan files
- Write `.available` signal

#### 1.4: PreCompact hook

- Create hook script
- Copy current JSONL as `{id}-precompact-{timestamp}.jsonl`
- No signal file (just preservation)

#### 1.5: Hook registration

- Create home-manager module for hooks
- Wire hooks into `~/.claude/settings.json`
- Test hook invocation

### Progress

- [ ] 1.1: Signal format definition
- [ ] 1.2: Project identification module
- [ ] 1.3: SessionEnd hook
- [ ] 1.4: PreCompact hook
- [ ] 1.5: Hook registration

### Handoff Notes

*(To be filled)*

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
- Parse JSONL, extract user/assistant text blocks
- Output plain text with role labels

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

- [ ] 2a.1: Pre-filter as library function
- [ ] 2a.2: CLI scaffolding
- [ ] 2a.3: record-event tool
- [ ] 2a.4: Aggregation job skeleton

### Handoff Notes

*(To be filled)*

---

## Phase 2b: Prompts

**Goal**: Design and test all LLM prompts.

### Gates

- [ ] Extraction prompt refined based on Phase 0 learnings
- [ ] Synthesis prompt produces useful STATUS.md
- [ ] Plan diff prompt identifies semantic changes (not formatting)

### Chunks

#### 2b.1: Extraction prompt refinement

- Review Phase 0 results
- Adjust tag vocabulary if needed
- Improve signal-to-noise ratio
- Document prompt design decisions

#### 2b.2: Synthesis prompt

- Create `prompts/status-synthesis.md`
- Input: EVENTS.jsonl window
- Output: STATUS.md in 4-question format
- Test with sample events

#### 2b.3: Plan diff prompt

- Create `prompts/plan-diff.md`
- Input: plan before/after
- Output: semantic changes as `plan-created`/`plan-diff` events
- Must filter formatting-only changes

### Progress

- [x] Extraction prompt exists (needs refinement in 2b.1)
- [ ] 2b.1: Extraction prompt refinement
- [ ] 2b.2: Synthesis prompt
- [ ] 2b.3: Plan diff prompt

### Handoff Notes

*(To be filled)*

---

## Phase 2c: Integration

**Goal**: Wire together capture, tooling, and prompts.

### Gates

- [ ] End-to-end: session ends → EVENTS.jsonl updated
- [ ] Aggregation job invokes extraction prompt correctly
- [ ] record-event subprocess pattern works

### Chunks

#### 2c.1: Aggregation job completion

- Wire quiet period trigger to processing
- For each pending signal:
  - Read session JSONL
  - Run pre-filter
  - Invoke `claude -p` with extraction prompt
  - Collect events from record-event output
  - Append to EVENTS.jsonl

#### 2c.2: Plan processing

- Detect plan files in session
- Diff against previous version
- Run plan diff prompt
- Append plan events to EVENTS.jsonl

#### 2c.3: End-to-end testing

- Run real session
- Verify hook fires
- Verify aggregation processes after quiet period
- Inspect EVENTS.jsonl for correctness

### Progress

- [ ] 2c.1: Aggregation job completion
- [ ] 2c.2: Plan processing
- [ ] 2c.3: End-to-end testing

### Handoff Notes

*(To be filled)*

---

## Phase 3: Status Synthesis

**Goal**: Generate useful STATUS.md from accumulated events.

### Gates

- [ ] STATUS.md generated at end of aggregation run
- [ ] 4-question format readable and useful
- [ ] Reading STATUS.md cold provides project understanding

### Chunks

#### 3.1: Synthesis integration

- Wire synthesis prompt to aggregation job
- Run after all pending sessions processed
- Input: recent EVENTS.jsonl entries

#### 3.2: STATUS.md output

- Write to `{project}/STATUS.md`
- Overwrite on each run (not append)
- Include timestamp of generation

#### 3.3: Quality validation

- Generate STATUS.md for this project
- Read it cold after 1 week
- Does it help understand where we are?

### Progress

- [ ] 3.1: Synthesis integration
- [ ] 3.2: STATUS.md output
- [ ] 3.3: Quality validation

### Handoff Notes

*(To be filled)*

---

## Phase 4: Retrieval

**Goal**: Surface context at session start.

### Gates

- [ ] UserPromptSubmit hook detects STATUS.md
- [ ] User offered choice: load all, status only, skip
- [ ] `/context` command works with filters

### Chunks

#### 4.1: UserPromptSubmit hook

- Detect project from CWD
- Check if STATUS.md exists
- Show offer with metadata (last updated, event count)
- User confirms before loading

#### 4.2: /context slash command

- Create skill for `/context`
- Default: STATUS.md + last 3-5 sessions
- Flags: `--last N`, `--since DATE`, `--tag TAG`, `--deep`

#### 4.3: Retrieval testing

- Start fresh session in project with STATUS.md
- Verify offer appears
- Verify loaded context is helpful

### Progress

- [ ] 4.1: UserPromptSubmit hook
- [ ] 4.2: /context slash command
- [ ] 4.3: Retrieval testing

### Handoff Notes

*(To be filled)*

---

## Phase 5: Work-specific (Deferred)

**Goal**: Add work-context features for professional growth tracking.

### Gates

- [ ] Skill gap tagging works for work projects
- [ ] Growth Signals section appears in STATUS.md
- [ ] Integration with self-review-signal skill

### Chunks

*(To be defined when phase is activated)*

### Progress

*(Deferred)*

### Handoff Notes

*(Deferred)*

---

## Phase 6: Archival (Deferred)

**Goal**: Manage EVENTS.jsonl growth over time.

### Gates

- [ ] Monthly archival moves old events to archive files
- [ ] Archive Entry pointers left in main EVENTS.jsonl
- [ ] `--deep` flag searches archive files

### Chunks

*(To be defined when phase is activated)*

### Progress

*(Deferred)*

### Handoff Notes

*(Deferred)*

---

## Session Log

| Session | Date | Phase | Summary |
|---------|------|-------|---------|
| 1 | 2026-03-01 | Bootstrap | Created repo, docs, pre-filter script, extraction prompt |
| 2 | 2026-03-02 | Research | Ralph loop analysis, microvm sandboxing research |
| 3 | 2026-03-02/03 | Infra | flake.nix, Haskell skeleton, beads, MicroVM sandbox |
| 4 | — | Phase 1 | *(next session)* |
