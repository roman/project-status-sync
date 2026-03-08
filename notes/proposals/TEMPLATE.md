# [Title: Short Descriptive Name]

**Date**: YYYY-MM-DD
**Status**: PROPOSED | APPROVED | REJECTED | SUPERSEDED
**Affects**: [modules, types, or subsystems touched]

## Problem Statement

What is broken, missing, or wrong today? Describe the observable symptom and its impact.
Do NOT describe the solution here — only the problem.

"We don't have feature X" is never a valid problem statement. Instead: "When Y happens,
the system does Z, which causes [concrete negative outcome]."

## The Real Question

Reframe the problem as the core design question that must be answered. This forces clarity
about what we're actually deciding.

## Decision Matrix

| Criterion | A: ... | B: ... | C: ... |
|-----------|:---:|:---:|:---:|
| ...       | ... | ... | ... |

Legend: :green_circle: good, :yellow_circle: acceptable, :red_circle: poor

### Option A: [Name]

[Description, pros, cons]

### Option B: [Name]

[Description, pros, cons]

## Recommendation: Option [X]

Why this option wins. Reference the matrix criteria that matter most.

### Concrete Changes

Numbered list of specific code/config modifications required.

### Trade-offs

What we give up by choosing this option. Be honest — every choice has a cost.

### Risk

Low/Medium/High with justification.

## Evolution Path

Conditions under which this decision should be revisited. Each item MUST have:
- **Trigger**: what milestone or event makes this worth revisiting
- **Question**: what specifically to re-evaluate
- **Reference**: which rejected option or new approach to consider

**MANDATORY**: After writing this section, register each item as a review gate in
WORKPLAN.md under the relevant phase's "Review gates" subsection:

```
**Review gates** (revisit after milestone):
- [ ] After [trigger]: [question] — See `notes/proposals/[this-file].md` § Evolution Path
```

If no evolution items exist, write "None — this decision is final or trivially reversible"
and explain why.

## Review Notes

Findings from code-critic or other review agents. Bullet points.
