# Status Synthesis

You are generating a project status document from accumulated events.

## Your Task

Synthesize project events into a STATUS.md that helps someone quickly re-orient to the project after time away.

## Input

You receive:
1. Project name
2. List of recent handoff files (for linking)
3. (Optional) Previous STATUS.md — if provided, update it with the new events
4. Events in compact tagged-line format (grouped by session, with date headers)

Each event group has a date and session prefix header, followed by tagged bullets:
`- [tag] description` where tag is one of: `decision`, `question`, `next`, `blocker`, `resolved`, `context`, `initiative`

## Incremental vs Full

- **Full synthesis** (no previous STATUS.md): Generate from scratch using all events provided.
- **Incremental synthesis** (previous STATUS.md provided): Update the existing status with the new events. Preserve information from the previous status that is still relevant. Remove information that has been superseded by newer events.

## Output Format

Generate markdown with this structure:

```markdown
# {Project Name}

> {One-line project description}

## Status

**Phase**: {current phase or work focus}
**Last Session**: {date} — {session_id}
**Blockers**: {list or "None"}

## Recent Handoffs

For detailed session context, see:
- [[handoffs/{filename}|{Topic} ({date})]]
- [[handoffs/{filename}|{Topic} ({date})]]

## Where We're At

- {Current work items with context}
- {Recent decisions made}
- {What's working / what's not}

## Where We're Going

- {Immediate next steps}
- {Open questions needing answers}
- {Planned phases if applicable}

## What We Know

- {Key decisions with rationale}
- {Technical constraints discovered}
- {Context that persists across sessions}

## What We Need to Know

- {Open questions}
- {Blockers requiring human input}
- {Uncertainties to resolve}
```

## Section Guidelines

### Status
- Phase: derive from recent `initiative` events or explicit phase references
- Blockers: from `blocker` events without matching `resolved` events

### Recent Handoffs
- Include 2-3 most recent handoff files as Obsidian wikilinks
- Format: `[[handoffs/2026-03-03-abc12345-topic|Topic Title (2026-03-03)]]`

### Where We're At
- Synthesize recent `context`, `decision`, and `resolved` events
- What state is the project in right now?

### Where We're Going
- From `next` events, unresolved `blocker` events
- What should the next session work on?

### What We Know
- From `decision` events (especially with rationale)
- Technical discoveries from `context` events
- Information that would be lost without documentation

### What We Need to Know
- From `question` events that remain unanswered
- From `blocker` events requiring external input
- Unknowns that affect planning

## Quality Criteria

- **Synthesize, don't summarize**: Group related events into coherent narratives
- **Current state focus**: Older events matter only if still relevant
- **Distinguish resolved vs open**: Check `resolved` tags to avoid stale blockers/questions
- **Concise**: Under 500 words total (quick re-orientation, not exhaustive history)
- **Actionable**: Next steps should be clear enough to start immediately

## Handling Event History

- Recent events (last 1-2 sessions): include details
- Older events: include only if still relevant (unresolved question, foundational decision)
- Resolved items: don't include unless the resolution itself is important context
- Superseded decisions: don't include (current decision wins)

## Example

Given events spanning 3 sessions with topics on MicroVM setup, session tracking, and Notes repo design:

```markdown
# Claude Conversation Sync

> Cross-session context awareness for Claude Code

## Status

**Phase**: Infrastructure / Design
**Last Session**: 2026-03-03 — abc12345
**Blockers**: None

## Recent Handoffs

For detailed session context, see:
- [[handoffs/2026-03-03-abc12345-notes-repo-protocol|Notes Repo Protocol (2026-03-03)]]
- [[handoffs/2026-03-03-def67890-session-tracking|Session Tracking (2026-03-03)]]

## Where We're At

- MicroVM sandbox functional: VM boots, project mounts at /project, isolation verified
- Session tracking module created for devenv (writes .current-session-id)
- Notes repo protocol designed: extraction → handoff → progress → status flow

## Where We're Going

- Create prompts: handoff-generation.md, progress-entry.md, status-synthesis.md
- Update docs/design.md with Notes repo architecture
- Implement capture hook to wire everything together

## What We Know

- Two-stage approach (extract events → synthesize status) preserves lossless history
- 9p filesystem shares work for VM project mounts (simpler than virtiofs)
- STATUS.md should link to recent handoffs via Obsidian wikilinks

## What We Need to Know

- How to handle monorepo subpaths in project identification?
- What quiet period is appropriate between session end and aggregation?
```

## Events

The events follow. Generate STATUS.md now.

---

