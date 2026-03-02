# Ralph Loop Setup Research — Research

**Date**: 2026-03-02
**Session**: Initial ralph loop exploration
**References**:
- ~/Projects/oss/iidy-hs (cloned and analyzed)
- ~/Projects/oss/microvm.nix (cloned)
- https://ghuntley.com/loop/

## Context

User wants to set up a "ralph loop" for autonomous Claude development on the
claude-conversation-sync project. The ralph loop is a pattern from ghuntley.com,
implemented comprehensively in iidy-hs.

This session focused on:
1. Understanding what the ralph loop is
2. Analyzing iidy-hs implementation
3. Identifying gaps in current project setup
4. Researching microvm.nix for sandboxed execution

## What Was Done

### 1. Cloned Reference Repositories

- `~/Projects/oss/iidy-hs` — Comprehensive ralph loop implementation
- `~/Projects/oss/microvm.nix` — Lightweight VM system for sandboxing

### 2. Analyzed iidy-hs Ralph Loop Components

Documented the 10 key components that iidy-hs has:

| Component | Purpose | Our Gap |
|-----------|---------|---------|
| `ralph-loop.sh` | Auto-restart, quota mgmt | None (manual only) |
| `WORKPLAN.md` | Single source of truth | Split plan.md + progress.md |
| `progress.log` | Real-time monitoring | No tail-f friendly format |
| `.msgs/` | Async human↔agent comms | None |
| `RALPH.md` | Headless mode instructions | None |
| Session size discipline | Proactive clean exits | None |
| End-of-session gates | Mandatory checkpoints | Suggested, not enforced |
| Research-first rule | Persist knowledge | Not required |
| Quota management | Survive rate limits | None |
| `notes/handoffs/` | Structured task docs | Single progress.md |

### 3. Researched `--dangerously-skip-permissions` Risk

iidy-hs uses this flag with only instructional mitigation (CLAUDE.md safety rules).
No technical enforcement. Analyzed what's at risk:
- Full home directory access
- Credentials (SSH, AWS, API keys)
- Other projects
- Host network

### 4. Designed MicroVM Sandboxing Architecture

Created comprehensive research doc: `notes/2026-03-02-microvm-sandboxing-research.md`

Key design:
- Run each ralph session in ephemeral NixOS VM
- Share only project directory via virtiofs
- VM destroyed after each session
- Credentials passed explicitly, not via home dir mount

## Key Decisions Made

1. **MicroVM over containers**: Separate kernel provides stronger isolation
2. **virtiofs over 9p**: Better performance for heavy I/O
3. **User networking**: Outbound only, no host network access
4. **Ephemeral VMs**: Destroyed after each session, no persistence
5. **QEMU hypervisor**: Most compatible, supports all share types

## What Was NOT Done

- [ ] No WORKPLAN.md created yet (need user decision on scope)
- [ ] No flake.nix created (need user decision on infrastructure)
- [ ] No ralph-loop.sh created (depends on sandboxing decision)
- [ ] No beads initialization (depends on above)

## Open Questions for User

1. **Full setup vs. minimal?**
   - Full: WORKPLAN, ralph-loop, flake, Haskell skeleton, beads
   - Minimal: Just ralph components, defer infrastructure

2. **Sandboxed from start?**
   - Yes: More setup work, but secure from day 1
   - No: Faster to start, add sandboxing later

3. **Git push from agent?**
   - Option A: Agent commits locally, human pushes (safest)
   - Option B: Mount SSH key read-only (agent can push)
   - Option C: GitHub token with limited scope

## Suggested Next Steps

### If proceeding with full setup:

1. **Create WORKPLAN.md** — Convert plan.md to ralph format with:
   - Phase index table
   - Gates per phase
   - Session tracking
   - Handoff notes section

2. **Create flake.nix** — With:
   - Haskell package derivation (nixDir structure)
   - microvm.nixosModules.microvm for claude-sandbox
   - devShell with cabal, ghc, haskell-language-server

3. **Create ralph-loop-sandboxed.sh** — Following iidy-hs pattern but:
   - Using microvm instead of direct claude invocation
   - Prompt written to `.ralph-prompt` file
   - VM reads prompt, runs claude, exits

4. **Create supporting files**:
   - `RALPH.md` — Headless mode instructions
   - `.msgs/` — Message inbox directory
   - `progress.log` — Empty, ready for appends
   - Update `CLAUDE.md` with ralph conventions

5. **Initialize beads** — For dependency tracking between phases

### If deferring sandboxing:

Same as above, but ralph-loop.sh runs claude directly (like iidy-hs).
Add sandboxing in a later phase.

## Files Created This Session

```
notes/
├── 2026-03-02-microvm-sandboxing-research.md   # MicroVM design doc
└── handoffs/
    └── 2026-03-02-ralph-loop-research.md       # This file
```

## Codebase Reference

| What | Where |
|------|-------|
| iidy-hs ralph-loop.sh | ~/Projects/oss/iidy-hs/scripts/ralph-loop.sh |
| iidy-hs WORKPLAN.md | ~/Projects/oss/iidy-hs/WORKPLAN.md |
| iidy-hs CLAUDE.md | ~/Projects/oss/iidy-hs/CLAUDE.md |
| iidy-hs RALPH.md | ~/Projects/oss/iidy-hs/RALPH.md |
| iidy-hs progress.log | ~/Projects/oss/iidy-hs/progress.log |
| microvm module options | ~/Projects/oss/microvm.nix/lib/options.nix |
| microvm examples | ~/Projects/oss/microvm.nix/examples/ |
| Our design doc | docs/design.md |
| Our plan | docs/plan.md |
| Our progress | docs/progress.md |
