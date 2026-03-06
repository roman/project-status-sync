# Haskell Development Skill Enrichment

**Date**: 2026-03-05
**Session**: 83827a14

## What happened

Cross-referenced haskell-development-skill against three Haskell blog sources:
- snoyman.com (~11 posts)
- haskellforall.com / Gabriel Gonzalez (~23 topic areas)
- cs-syd.eu / Tom Sydney Kerckhove (~16 topic areas)

## Process

1. Extracted ~200 individual practices from all three sources
2. Added all plausible candidates to skill (bloated to 172 lines / 673 examples)
3. Ran code-critic audit — flagged scope creep and academic bloat
4. User re-scoped: skill is general-purpose (not project-specific), will live in own repo
5. Re-ran code-critic with general-purpose framing — most items justified
6. User pruned testing-philosophy items and niche library recommendations
7. Final result: focused, opinionated skill at 139 lines / 455 examples

## What was added (kept after review)

- Module organization (vertical by domain, explicit exports, single library stanza)
- Smart constructors + `.Internal` modules
- Compact vs non-compact strictness
- Evidence types at API boundaries (softened from "no boolean blindness")
- No Float/Double for quantities
- No `foldl` (use `foldl'`)
- Ad-hoc polymorphism caution
- Custom exception types with context fields
- `orDie` combinators
- `NonEmpty` over `[a] -> Maybe a`
- `-Werror=missing-fields`
- Softened point-free, `RecordWildCards` for record assembly
- Algebraic design (Ap deriving, foldMap, law verification)
- RIO activation guard

## What was cut (after review)

- genvalidity (all sections) — niche library, not widely adopted
- Weeder — no git-hook available, hard to enforce
- Testing portfolio, golden tests, conformance testing, test isolation, no mocking — testing philosophy, not Haskell conventions
- autodocodec + layered configuration — library advocacy
- Free monads / DSL pattern — premature abstraction
- Avoid `($)` — bikeshed, contradicts ecosystem
- TypeError poison — too clever for default agent behavior
- ApplicativeDo as default extension — subtle interactions

## Key decision

Skill is RIO-opinionated with an activation guard. If a project doesn't use RIO, the skill doesn't apply.
