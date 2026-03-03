# Handoff: Notes Repo Protocol Design

**Date**: 2026-03-03
**Session**: no-sessio (session tracking not active)
**Plan**: [docs/plans/2026-03-03-notes-repo-protocol-design.md](../../docs/plans/2026-03-03-notes-repo-protocol-design.md)

## What Was Done

- Explored iidy-hs and claude-conversation-sync to understand existing workflow protocols
- Designed Notes repo approach for projects where docs can't live in-repo
- Created comprehensive plan comparing iidy-hs (in-repo, single agent) vs Notes repo (external, two agents)
- Key architectural decision: Keep EVENTS.jsonl (two-stage extract → synthesize) rather than direct synthesis
- Defined document structures: STATUS.md (4-question format), handoffs (descriptive summaries), progress.log (same format)
- Defined processing flow order: extraction → handoff → progress → status (status last so it can link to new handoff)

## Key Decisions

1. **EVENTS.jsonl retained**: Lossless history prevents "telephone game" effect of successive summarizations
2. **Two-agent architecture**: Working agent exits, summarization agent (via capture hook) reads conversation and generates docs
3. **STATUS.md replaces WORKPLAN**: Descriptive (state) rather than prescriptive (plan), 4-question format
4. **Handoff filename format**: `YYYY-MM-DD-{sessionID}-{topic}.md`
5. **STATUS.md includes handoff links**: Recent Handoffs section with Obsidian wikilinks
6. **Context injection via CLAUDE.md**: No automatic hook, project CLAUDE.md tells agent where to find STATUS.md
7. **No dashboard**: Removed cross-project dashboard functionality per user request

## What's Next

- Update `docs/design.md` with Notes repo architecture (integrate plan into design doc)
- Update `docs/plan.md` with Notes repo phases
- Create the prompts:
  - `prompts/handoff-generation.md`
  - `prompts/progress-entry.md`
  - `prompts/status-synthesis.md`
- Add module options for `notesBasePath`, `orgMappings`, `projectOverrides`

## Notes

- The full plan with detailed contrast tables, structure examples, and draft prompts is at `docs/plans/2026-03-03-notes-repo-protocol-design.md`
- iidy-hs handoffs are prescriptive task briefs (~100-500 lines); proposed handoffs are descriptive summaries (~50-150 lines)
- Working agent reads STATUS.md + handoffs from Notes repo at session start (via CLAUDE.md instructions)
- Summarization agent writes to Notes repo after session ends (via capture hook)
