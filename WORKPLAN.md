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
| 1 | Capture: hooks + signals | DONE (verify build) | — |
| 2a | Tooling: pre-filter, record-event, aggregation | PENDING | Infra, Phase 1 (signal format) |
| 2b | Prompts: extraction, handoff, progress, synthesis | PARTIAL | Infra |
| 2c | Integration: wire everything together | PENDING | 1, 2a, 2b |
| 3 | Status & Handoffs: generate outputs | PENDING | 2c |
| 4 | Retrieval: context injection (optional) | DEFERRED | 3 |
| 5 | Archival: manage EVENTS.jsonl growth | DEFERRED | 4 |

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

**Status**: ABANDONED (2026-03-03)

**Goal**: Enable safe ralph loops by running Claude in ephemeral NixOS VMs.

**Why abandoned**: Fundamental issues with sharing /nix/store made it impractical:
- 9p too slow for nix store access patterns
- virtiofs required complex host daemon setup
- nix database not shared, causing redundant fetches
- Read-only squashfs root conflicted with writable store needs

See: `notes/handoffs/2026-03-03-microvm-abandoned.md`

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

#### 2026-03-03 — Microvm config migrated to nixDir conventions

**Completed**:
- Moved `nix/microvm/claude-sandbox.nix` → `nix/configurations/nixos/claude-sandbox/`
- Now uses nixDir auto-discovery for nixosConfigurations
- Removed manual `flake = { nixosConfigurations = ... }` from flake.nix

**Bug Fixed in nixDir**:
- `importWithInputs` option wasn't being respected for flake-level configurations
- Fixed in local nixDir (commit 0527f2c on v3 branch)
- See: `notes/handoffs/2026-03-03-nixdir-configuration-fix.md`

**Structure**:
```
nix/configurations/nixos/claude-sandbox/
├── default.nix        # nixDir entry: inputs: { system, modules }
└── configuration.nix  # NixOS module with microvm config
```

#### 2026-03-03 — Nix-serve substituter for VM

**Completed**:
- Configured sandbox VM to use host's nix-serve as substituter
- `http://10.0.2.2:5000` (QEMU user-mode gateway) as primary substituter
- Falls back to `cache.nixos.org` if host unavailable
- Resolves nix store caching issue without needing closure.json files

**Requires**: Host machine must run `services.nix-serve` on port 5000

**Updated**: `notes/handoffs/2026-03-03-microvm-nix-store-caching.md`

#### 2026-03-04 — RALPH audit & script suite

**Completed**:
- Audited RALPH.md (9 issues found), rewrote for bubblewrap sandbox reality
- Added design gate (proposals for one-way-door decisions) and code-critic review step
- Renamed ralph-test.sh → ralph-oneshot.sh
- Created ralph-loop.sh (loop runner with exit code handling)
- Created ralph-msg.sh (reqID-based async messaging)
- All logs moved to project-local `tmp/` directory
- Message inbox protocol: `<id>.md` → `<id>.reply.md`

See: `notes/handoffs/2026-03-04-ralph-scripts-audit.md`

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

### Handoff Notes

#### 2026-03-04 — Phase 1.1 signal format definition

**Completed**:
- Created `CCS.Signal` module with `SignalPayload` type + Aeson instances
- JSON schema: `{"transcript_path": "...", "cwd": "..."}`
- `readSignal`/`writeSignal` file I/O helpers
- JSON round-trip and decode tests in `test/Main.hs`
- Example signal file at `docs/examples/signal-available.json`

**Note**: Build not verified (ran in sandbox without cabal/ghc). Verify with `cabal build && cabal test`.

**Next**: Phase 1.2 (project identification module) or Phase 1.3 (SessionEnd hook script)

#### 2026-03-05 — Phase 1.2 project identification module

**Completed**:
- Created `CCS.Project` module with `ProjectKey`, `ProjectName`, `Project` types
- `identifyProject` shells out to git for remote URL and root path
- `normalizeRemoteUrl` normalizes SSH (SCP-style), ssh://, https://, http:// to `host/path`
- Monorepo support: appends relative subpath from git root to key
- Directory fallback for non-git projects (uses last path component)
- 9 unit tests for URL normalization (SSH/HTTPS equivalence, token auth, corporate hosts)

**Note**: Build not verified (ran in sandbox without cabal/ghc). Verify with `cabal build && cabal test`.

**Next**: Phase 1.3 (SessionEnd hook script) or Phase 1.4 (hook registration)

#### 2026-03-05 — Phase 1.3 SessionEnd hook script

**Completed**:
- Created `scripts/session-end-hook.sh` — reads Claude Code hook JSON from stdin
- Extracts `session_id`, `transcript_path`, `cwd` from stdin payload
- Writes `{signal_dir}/{session_id}.available` containing SignalPayload JSON
- Signal dir: `$CCS_SIGNAL_DIR` or `${XDG_STATE_HOME}/ccs/signals/` (XDG default)
- Silently exits on missing fields (hook must stay fast)
- Tested: correct signal output, missing field handling, extra field stripping

**Note**: Build not verified (sandbox lacks cabal/ghc). No Haskell changes in this chunk.

**Next**: Phase 1.4 (hook registration via home-manager module)

#### 2026-03-05 — Phase 1.4a+b hook registration packaging

**Completed**:
- Created `nix/packages/ccs-session-end-hook/default.nix` — `writeShellApplication` wrapping hook script
- Runtime dep: `jq` (added to PATH automatically via `runtimeInputs`)
- Created `nix/modules/home-manager/ccs-session-end-hook/default.nix`
- Option namespace: `programs.claude-code.plugins.conversation-sync`
- Sets `programs.claude-code.settings.hooks.SessionEnd` hook entry
- Optional `signalDir` option to override `CCS_SIGNAL_DIR`
- Follows exact pattern from haskell-development-skill module

**Not verified**: No nix tools in sandbox. Needs `nix build .#ccs-session-end-hook` on host.

**Remaining**: 1.4c verification (must be done outside sandbox)

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
- [ ] 2b.1: Extraction prompt refinement
- [x] 2b.2: Synthesis prompt (`prompts/status-synthesis.md`)
- [x] 2b.3: Handoff generation prompt (`prompts/handoff-generation.md`)
- [x] 2b.4: Progress entry prompt (`prompts/progress-entry.md`)

### Handoff Notes

#### 2026-03-03 — Notes repo prompts created

**Completed**:
- Created `prompts/status-synthesis.md` — synthesizes STATUS.md from EVENTS.jsonl
- Created `prompts/handoff-generation.md` — creates session handoff from events
- Created `prompts/progress-entry.md` — generates single-line progress.log entry

**Architecture**: Processing order is extraction → handoff → progress → status (status last so it can link to the new handoff via Obsidian wikilinks).

**Remaining**: Extraction prompt refinement (2b.1)

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

- [ ] 2c.1: Aggregation job completion
- [ ] 2c.2: End-to-end testing

### Handoff Notes

*(To be filled)*

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

- [ ] 3.1: Processing flow integration
- [ ] 3.2: Handoff output
- [ ] 3.3: STATUS.md output
- [ ] 3.4: Quality validation

### Handoff Notes

*(To be filled)*

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

### Handoff Notes

*(Deferred)*

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

### Handoff Notes

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

Tasty + tasty-quickcheck + genvalidity. Validity/GenValid instances,
forAllValid, producesValid combinators. Patterns from mergeful/mergeless.

### Tooling

- Fourmolu (formatter) — git pre-commit hook
- HLint (linter) — git pre-commit hook

### Handoff Notes

#### 2026-03-04 — Initial creation

**Completed**:
- SKILL.md with 14 convention sections
- references/examples.md with ~15 BAD/GOOD code pairs
- Nix package, home-manager module, devenv module
- Git-hooks for fourmolu and hlint
- Verified: `nix build .#haskell-development-skill` and `nix develop --impure`

**Research sources**: RIO library, NorfairKing/mergeful, NorfairKing/mergeless

#### 2026-03-04 — RIO conventions applied to codebase

**Completed**:
- Refactored all source files to RIO conventions (NoImplicitPrelude, strict fields, Text, MonadIO library sigs)
- Added `rio` dependency, shared `common extensions` stanza, expanded GHC warnings
- `runSimpleApp` + `logInfo` in app/Main.hs
- Verified: `cabal build` + `cabal test` (3/3 pass)

**Deferred**: Full App record/Has* (no state yet), genvalidity (few types), structured logging (no operations yet)

See: `notes/handoffs/2026-03-04-rio-refactor.md`

---

## Supplementary: Session Tracking

**Goal**: Enable tracing progress.log entries back to conversation transcripts.

### Implementation

- Devenv module at `nix/modules/devenv/session-tracking.nix`
- Exported as `devenvModules.session-tracking`
- `UserPromptSubmit` hook writes session ID to `.current-session-id`
- Agents include session prefix in progress.log entries
- Format: `YYYY-MM-DD HH:MM [<8-char-prefix>] — Phase X.Y: description`

### Handoff Notes

#### 2026-03-03 — Session tracking module

**Completed**:
- Created `nix/modules/devenv/session-tracking.nix` (devenv module)
- Exported as `devenvModules.session-tracking` via nixDir
- Updated `CLAUDE.md` progress logging format to include session prefix
- Added `.current-session-id` to `.gitignore`

**Usage**:
```nix
# In devenv.nix or via flake imports:
imports = [ inputs.ccs.devenvModules.session-tracking ];
```

**Update 2026-03-03**: Project now uses devenv with session-tracking module enabled.
The nixdir-skill is also installed for better assistance with nixDir flake structures.
