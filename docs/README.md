# Documentation

## Start Here

1. Read [`../WORKPLAN.md`](../WORKPLAN.md) for current status and handoff notes
2. Check `beads` for available tasks: `cd beads && bd ready`
3. Review [plan.md](plan.md) for original phase design

## Contents

| Document | Purpose |
|----------|---------|
| [design.md](design.md) | System architecture, domain model, data formats, types |
| [plan.md](plan.md) | Original phased implementation plan |
| [decisions/](decisions/) | Architecture Decision Records (ADRs) |

**Note**: `WORKPLAN.md` (in project root) is the live version of the plan with
session tracking and handoff notes. `plan.md` is the original reference.

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
