# Handoff: S.PS.6c — Nix Module Wiring

**Date**: 2026-03-11
**Role**: Implementer

## What Was Done

Wired `orgMappings` and `projectOverrides` module options into the
`aggregateArgs` command list in the project-status-sync home-manager
module. When a user configures these options, the generated systemd
service / launchd agent command now includes the corresponding
`--org-mapping KEY=VALUE` and `--project-override KEY=PATH` flags.

Also removed stale "blocked on CLI support" text from option descriptions
since S.PS.6b landed the CLI flags.

Files changed:
- `nix/modules/home-manager/project-status-sync/default.nix`

## Spec Compliance

WORKPLAN item: "S.PS.6c: Nix module — wire orgMappings/projectOverrides options to CLI flags"
- Approved proposals checked: none affecting Nix module
- Update `aggregateCommand` to pass flags from module options: met
- Remove "blocked on CLI" notes from module options: met

## What's Next

- S.PS.4: Integration in zoo.nix (requires interactive session — sandbox constraint)
- S.PS.5: Verification (requires home-manager switch — sandbox constraint)
