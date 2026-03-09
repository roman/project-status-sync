# Handoff: S.PS.2 project-status-sync home-manager module

**Date**: 2026-03-09
**Session**: 02fb4bf4
**Role**: Implementer

## What Was Done

Created `nix/modules/home-manager/project-status-sync/default.nix` — the unified
home-manager module that registers both the SessionEnd hook (capture) and a periodic
timer service (processing).

Module options namespace: `programs.project-status-sync`. All 10 options from the WORKPLAN
spec are implemented (enable, package, signalDir, outputDir, quietPeriodMinutes,
intervalMinutes, llmCommand, llmArgs, orgMappings, projectOverrides).

Key implementation details:
- SessionEnd hook uses `lib.mkAfter` for composability with other hooks
- systemd service + timer on Linux, launchd agent on macOS (platform-conditional via mkIf)
- Shared `aggregateArgs` list avoids command duplication between platforms
- Linux uses `writeShellScript` wrapper for correct shell quoting of ExecStart
- macOS uses `ProgramArguments` list directly (no shell quoting needed)
- Mutual exclusion assertion prevents simultaneous use with old `ccs-session-end-hook` module

## Spec Compliance

WORKPLAN item: "S.PS.2: project-status-sync home-manager module"

- Approved proposals checked: none affecting Nix modules
- Create `nix/modules/home-manager/project-status-sync/default.nix`: met
- Registers SessionEnd hook via `lib.mkAfter`: met
- Asserts `programs.claude-code.enable` with readable error message: met
- Platform-conditional: systemd on Linux, launchd on macOS: met
- Auto-discovered by nixDir: met (directory convention)
- All 10 options from spec table: met
- Mutual exclusion with old module: met (assertion added per code-critic finding)

## Code Critic Findings (addressed)

1. **MAJOR**: Duplicate command construction between Linux/macOS — fixed by reusing
   `aggregateArgs` for launchd `ProgramArguments`
2. **MAJOR**: No guard against simultaneous enablement with old module — fixed by adding
   assertion on `!config.programs.claude-code.plugins.conversation-sync.enable`

## What's Next

- S.PS.3: Deprecate ccs-session-end-hook module
- S.PS.4: Integration in zoo.nix
- S.PS.5: Verification (mechanical checks unblocked, quality judgment blocked by 3.4)
