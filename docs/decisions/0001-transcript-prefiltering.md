# 0001. Pre-filter Session Transcripts Before LLM Processing

**Date**: 2026-03-01

**Status**: accepted

## Context

Claude Code session JSONL files are large (1-16MB) and contain:
- Tool results (file contents, command output)
- Progress updates
- File history snapshots
- Thinking blocks

Passing raw JSONL to the extraction LLM:
- Exceeds token limits for large sessions
- Wastes tokens on structural JSON overhead
- Includes noise irrelevant to summarization

## Decision

Pre-filter JSONL before LLM invocation:
1. Extract only `user` and `assistant` message entries
2. From those, extract only `text` content blocks
3. Output as plain text with role labels (`USER:`, `ASSISTANT:`)

Implementation: `scripts/jsonl-to-summary-input.sh`

## Consequences

**Positive**:
- 99% size reduction (1.6MB → 19KB typical)
- Plain text is ~10% more token-efficient than JSON
- Easier for LLM to parse conversation flow
- Fits within token limits for all observed sessions

**Negative**:
- Loses tool call context (what files were read/edited)
- May miss context from tool results that informed decisions

**Neutral**:
- Filtering logic must handle both string and array content formats
- Script requires `jq` dependency
