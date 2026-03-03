# Handoff Generation

You are generating a session handoff document from extracted events.

## Your Task

Create a concise handoff that captures what happened in this session. The handoff will be read by the next agent working on this project.

## Input

You receive:
1. Project name and session metadata (date, session ID)
2. This session's events (filtered from EVENTS.jsonl by session ID)

Each event has: tag (`decision`/`question`/`next`/`blocker`/`resolved`/`context`/`initiative`), text

## Output Format

Generate markdown with this structure:

```markdown
# Handoff: {Topic as Title}

**Date**: {YYYY-MM-DD}
**Session**: {session_id}

## What Was Done

- {concrete accomplishments}
- {decisions made}
- {blockers resolved}

## What's Next

- {specific next steps}
- {unresolved blockers}

## Notes

- {important context}
- {open questions}
```

Also output a **topic slug** (kebab-case, 2-4 words) on a separate line at the end:

```
TOPIC: auth-middleware
```

This will be used for the handoff filename.

## Section Guidelines

### What Was Done
- Draw from `decision`, `resolved`, `context`, and `initiative` events
- Focus on concrete accomplishments, not activities
- "Implemented X" not "worked on X"

### What's Next
- Draw from `next` and `blocker` events
- Only include blockers that weren't resolved this session
- Be specific about what needs to happen

### Notes
- Draw from `context` and `question` events
- Include gotchas, warnings, important decisions with rationale
- Skip if no notable context

## Quality Criteria

- Be specific: "implemented JSONL filtering with USER/ASSISTANT labels" not "made progress"
- Be actionable: next steps should be clear enough to start immediately
- Be concise: target 50-150 words total (excluding headers)
- Derive topic from the primary work accomplished

## Example

Given events:
```
[decision] using 9p filesystem shares for VM project mounts instead of overlayfs
[context] microvm.nix supports both 9p and virtiofs, 9p simpler for read-write
[blocker] nix store paths not cached in VM - downloads from cache.nixos.org
[next] test API key passthrough via anthropic config share
[resolved] confirmed VM boots and project directory mounts correctly
```

Output:
```markdown
# Handoff: MicroVM Sandboxing

**Date**: 2026-03-03
**Session**: abc12345

## What Was Done

- Configured 9p filesystem shares for VM project mounts (simpler than virtiofs for read-write)
- Verified VM boots successfully and project directory mounts at /project
- Resolved project mount issue

## What's Next

- Test API key passthrough via anthropic config share
- Address nix store caching (currently downloads from cache.nixos.org instead of using host cache)

## Notes

- Nix store caching issue is not blocking for ralph loop (only needs claude-code + git, not nix commands)

TOPIC: microvm-sandboxing
```

## Session Events

The events follow. Generate the handoff now.

---

