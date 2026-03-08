# Session Event Extraction

You are analyzing a Claude Code conversation transcript to extract meaningful project events.

## Your Task

Read the conversation and extract **only significant observations** that would help someone understand the project's state, decisions made, and work in progress. Output one event per line in the format described below.

## Transcript Format

The transcript uses role labels to identify speakers:

- **USER:** — the human's messages
- **ASSISTANT:** — Claude's visible responses
- **THINKING:** — Claude's internal reasoning (not shown to the user)

THINKING blocks are often the most information-dense content. They contain the reasoning behind decisions, alternatives considered, and technical discoveries. Pay close attention to them.

## Event Tags

Use exactly one tag per event:

| Tag | When to use |
|-----|-------------|
| `decision` | A choice was made between alternatives. Must name what was chosen and what was rejected or why. |
| `question` | An open question that remains unanswered at session end. Skip if resolved in the same session. |
| `next` | Concrete next step identified. Must be specific enough to start immediately. |
| `blocker` | Something preventing progress. External dependency, missing info, or technical obstacle. |
| `resolved` | A previous question or blocker was answered/unblocked in this session. Include what was resolved and how. |
| `context` | Important background information discovered. Technical constraints, existing patterns, API behaviors, gotchas. |
| `initiative` | A new workstream or feature being started. Most sessions should have zero of these — only for entirely new workstreams, not subtasks or phase transitions. |

## Quality Criteria

**Extract when**:
- The observation would be useful 2 weeks from now
- Someone unfamiliar with the session would benefit from knowing it
- It captures a non-obvious decision or discovery
- It records a technical constraint or gotcha that would be rediscovered painfully

**Skip when**:
- It's a routine code change (adding imports, fixing typos, renaming variables)
- It's debugging noise: error messages, stack traces, retry attempts
- It's false starts or abandoned approaches that led nowhere
- It's obvious from reading the code diff itself
- It's the LLM talking through implementation steps without making a decision
- It's tool output (file contents, test results) unless revealing something surprising
- It's a question that was asked and answered within the same session (neither `question` nor `resolved` — just skip it)

**Quantity guidance**: A typical 30-minute session produces 3-7 events. An intensive session might produce 8-12. If you're extracting more than 15, you're likely capturing noise. If you found 0-1 events and the session was non-trivial, revisit THINKING blocks — but do not invent events to meet a quota.

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
- Self-contained — don't reference "the file" or "the issue" without naming them

If the session contains no significant events, output nothing. An empty result is valid.

## Examples

Good extractions:
```
[decision] chose 9p filesystem over virtiofs for VM project mounts — simpler for read-write, virtiofs requires host daemon
[context] Claude Code JSONL thinking blocks use field name "thinking" not "text", with a separate "signature" field
[blocker] home-manager MCP module interface not yet defined — blocks hook registration
[next] test API key passthrough via anthropic config share in sandbox
[resolved] confirmed home-manager supports WatchPaths natively via launchd.agents — no custom plist needed
[initiative] starting Phase 2: processing infrastructure (pre-filter, record-event, aggregation)
[question] how should monorepo subpaths map to project keys when multiple projects share a git remote
```

Bad extractions (do not do):
```
[context] looked at some files  # too vague — which files? what was learned?
[decision] fixed the bug  # not a decision, and no specifics
[next] continue working on this  # not actionable — working on what?
[question] how does this work  # too vague, likely resolved in-session
[context] ran cabal build  # routine, no information value
[decision] added an import  # trivial code change, not a decision
```

## Conversation Transcript

The transcript follows. Extract events now.

---

