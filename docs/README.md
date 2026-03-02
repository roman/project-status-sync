# Documentation

## Start Here

1. Read [progress.md](progress.md) for context from previous agents
2. Check `beads` for available tasks: `cd beads && bd ready`
3. Review [plan.md](plan.md) to understand current phase

## Contents

| Document | Purpose |
|----------|---------|
| [design.md](design.md) | System architecture, domain model, data formats, types |
| [plan.md](plan.md) | Phased implementation plan with parallelization |
| [progress.md](progress.md) | Agent handoff notes — what was done, what's next |
| [decisions/](decisions/) | Architecture Decision Records (ADRs) |

## ADRs

| # | Decision |
|---|----------|
| [0001](decisions/0001-transcript-prefiltering.md) | Pre-filter session transcripts before LLM processing |

## Tracking Work

```bash
cd beads
bd ready                 # See unblocked tasks
bd show <id>             # Get task details
bd update <id> --status in_progress
bd close <id>
bd sync
```
