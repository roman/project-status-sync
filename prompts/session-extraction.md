# Session Event Extraction

You are analyzing a Claude Code conversation transcript to extract meaningful project events.

## Your Task

Read the conversation and extract **only significant observations** that would help someone understand the project's state, decisions made, and work in progress. Call `record-event` for each observation.

## Event Tags

Use exactly one tag per event:

| Tag | When to use |
|-----|-------------|
| `decision` | A choice was made between alternatives. Must be actionable and specific. |
| `question` | An open question that remains unanswered. Skip if resolved in the same session. |
| `next` | Concrete next step identified. Must be actionable, not vague. |
| `blocker` | Something preventing progress. External dependency, missing info, or technical obstacle. |
| `resolved` | A previous question or blocker was answered/unblocked in this session. |
| `context` | Important background information discovered. Technical constraints, existing patterns, API behaviors. |
| `initiative` | A new workstream or feature being started. Use sparingly — only for significant new efforts. |

## Quality Criteria

**Extract when**:
- The observation would be useful 2 weeks from now
- Someone unfamiliar with the session would benefit from knowing it
- It captures a non-obvious decision or discovery

**Skip when**:
- It's a routine code change without architectural significance
- It's asking clarifying questions about implementation details
- It's debugging noise or false starts that were abandoned
- It's obvious from reading the code itself

## Output Format

Output one event per line:

```
[tag] observation text
```

The observation should be:
- A complete sentence or phrase (no trailing periods needed)
- Written in present tense for current state, past tense for decisions
- Specific enough to be useful without the full conversation context
- 10-50 words typically

## Examples

Good extractions:
```
[decision] using yaml-language-server for JSON/YAML schema validation instead of separate servers
[context] Claude Code stores sessions under opaque directory names derived from URL-encoded paths
[blocker] home-manager MCP module interface not yet defined
[next] wire up SessionEnd hook to copy modified plan files
[resolved] confirmed home-manager supports WatchPaths natively via launchd.agents
```

Bad extractions (do not do):
```
[context] looked at some files  # too vague
[decision] fixed the bug  # no specifics
[next] continue working on this  # not actionable
[question] how does this work  # too vague, likely resolved
```

## Conversation Transcript

The transcript follows. Extract events now.

---

