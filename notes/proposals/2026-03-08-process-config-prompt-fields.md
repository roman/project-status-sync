# ProcessConfig Prompt Fields: Maybe or Mandatory?

**Date**: 2026-03-08
**Status**: APPROVED
**Affects**: `CCS.Process.ProcessConfig`, `Main.AggregateCmd`, `processSession` pipeline

## Problem Statement

`ProcessConfig` carries four prompt paths: extraction (mandatory) plus handoff, progress,
and the upcoming synthesis prompt (all `Maybe FilePath`). The CLI exposes the optional ones
via `optional (option str ...)`, and the pipeline silently skips generation when `Nothing`.

This creates a failure mode where a user forgets `--handoff-prompt` and the system happily
runs extraction-only, producing no handoff or progress output. The failure is silent. The
user discovers it later, maybe never.

Phase 3.3 adds a synthesis prompt (STATUS.md generation), making this a 4th prompt field.
The `AggregateCmd` constructor already has 6 positional fields; a 7th makes the problem
worse.

## The Real Question

Are these prompts optional features or required components of the pipeline?

Looking at `processSession`, the function always extracts events, then unconditionally calls
`generateHandoff` and `generateProgressEntry`. Those functions pattern-match on `Maybe` and
silently `pure ()` when `Nothing`. There is no documented use case for extraction-only runs.
The pipeline was designed to produce all three (soon four) outputs together.

**Conclusion**: These are required components. The `Maybe` is an accident of incremental
development, not a design choice.

## Decision Matrix

| Criterion                 | A: Keep Maybe | B: All Mandatory | C: PromptBundle | D: Auto-discover |
|---------------------------|:---:|:---:|:---:|:---:|
| Simplicity                | :green_circle: | :green_circle: | :green_circle: | :red_circle: |
| Correct failure mode      | :red_circle: | :green_circle: | :green_circle: | :yellow_circle: |
| Field count reduction     | :red_circle: | :red_circle: | :green_circle: | :yellow_circle: |
| Future-proof (synthesis)  | :yellow_circle: | :yellow_circle: | :green_circle: | :green_circle: |
| Implementation effort     | :green_circle: | :green_circle: | :green_circle: | :red_circle: |
| Deletion cost (reversal)  | :green_circle: | :green_circle: | :green_circle: | :red_circle: |

Legend: :green_circle: good, :yellow_circle: acceptable, :red_circle: poor

### Option A: Keep Maybe, Document as Optional

Leave `ProcessConfig` as-is. Add documentation that prompts should be provided.

- **Pro**: Zero code change.
- **Con**: Silent failure persists. Documentation does not prevent misconfiguration.
  Adding synthesis means another `Maybe FilePath` field, another `optional` in the CLI,
  another silent skip. The problem grows.

### Option B: All Fields Mandatory in ProcessConfig

Remove `Maybe` from handoff/progress prompt fields. CLI parser uses `option str` (required)
instead of `optional`. If a user omits `--handoff-prompt`, optparse-applicative prints a
usage error. Loud, immediate.

- **Pro**: Simplest change. Every field is `!FilePath`, no `Maybe` matching in pipeline.
  `generateHandoff` and `generateProgressEntry` lose their outer `case` branch.
- **Con**: `AggregateCmd` still has many positional fields (6 today, 7 with synthesis).
  Does not address the structural problem.

### Option C: PromptBundle Record

Introduce a `PromptBundle` record grouping all prompt paths:

```haskell
data PromptBundle = PromptBundle
  { pbExtraction :: !FilePath
  , pbHandoff    :: !FilePath
  , pbProgress   :: !FilePath
  , pbSynthesis  :: !FilePath  -- added in Phase 3.3
  }
  deriving stock (Show)
```

`ProcessConfig` becomes:

```haskell
data ProcessConfig = ProcessConfig
  { pcOutputDir :: !FilePath
  , pcPrompts   :: !PromptBundle
  , pcCommand   :: !FilePath
  , pcCommandArgs :: ![String]
  }
```

`AggregateCmd` drops from 6 fields to 4 (signal-dir, quiet-minutes, output-dir,
prompt-bundle parsed from flags). Adding synthesis later means adding one field to
`PromptBundle`, not touching `ProcessConfig` or `AggregateCmd`.

- **Pro**: All the benefits of B plus field count reduction. Prompt concerns are grouped.
  Adding the 4th prompt is a one-line addition to `PromptBundle`. `processSession` receives
  a clear bundle instead of reaching into four separate fields.
- **Con**: One new type definition. Marginally more code than B. (But less code overall
  because pattern-match branches on `Maybe` are deleted.)

### Option D: Auto-discover from Well-Known Paths

Ship prompts at known paths (`$XDG_DATA_HOME/ccs/prompts/extraction.md`, etc.). CLI falls
back to these paths when flags are omitted.

- **Pro**: Zero flags needed in the common case.
- **Con**: Introduces filesystem convention coupling, XDG lookup logic, fallback chains.
  Complex for a tool run from a Nix-managed environment where paths are store-hashed.
  Hard to delete if the convention proves wrong. Solves a UX problem we don't have yet
  (the CLI is called from a script, not typed by hand).

## Recommendation: Option B (All Mandatory)

After code-critic review, Option B is preferred over C. The PromptBundle abstraction groups
prompts by coincidence (they're configured together) rather than by concept (they serve
different pipeline stages). This makes it premature — it adds a type that doesn't earn its
keep yet.

Option B achieves the core goal (loud failures instead of silent skipping) with less code.
If Phase 3.3 makes the field count genuinely painful, bundling can be reconsidered then with
real evidence.

### Concrete Changes

1. **Modify `ProcessConfig`**: Change `pcHandoffPrompt` and `pcProgressPrompt` from
   `!(Maybe FilePath)` to `!FilePath`
2. **Modify `AggregateCmd`**: Change the two `!(Maybe FilePath)` fields to `!FilePath`
3. **Modify `aggregateParser`**: Replace `optional (option str ...)` with `option str ...`
   (required) for `--handoff-prompt` and `--progress-prompt`
4. **Modify `generateHandoff`/`generateProgressEntry`**: Remove outer `case` on `Maybe`,
   take `FilePath` directly
5. **Phase 3.3**: Add `pcSynthesisPrompt :: !FilePath` to `ProcessConfig`, add required
   `--synthesis-prompt` flag to CLI. Straightforward one-field addition.

### Trade-offs

- We lose the ability to run extraction-only. If that use case materializes, the correct
  response is a separate `extract-only` subcommand, not optional fields on `aggregate`.
- All prompt files must exist on disk. This is the correct failure mode: if a prompt file
  is missing, the pipeline should fail at startup, not silently produce incomplete output.

### Risk

Low. This is a reversible refactor touching types and plumbing. No behavioral change for
correctly-configured invocations. The compiler will catch every call site that needs updating.

### Evolution Path

- **Trigger**: Phase 3.3 lands. **Question**: Is field count now painful enough for PromptBundle (Option C)? **Reference**: Option C in this proposal.
- **Trigger**: Phase 3.3 lands. **Question**: Has extraction-only become a real need? **Reference**: add `ccs extract` subcommand with its own config.

Registered as review gates in WORKPLAN.md § Phase 2c.

### Review Notes (code-critic)

- PromptBundle dismissed as premature abstraction — groups by config proximity, not concept
- Option B achieves same failure-mode fix with fewer lines and no new types
- Extraction-only is hypothetical, not a stated requirement — no reversal cost concern
- Recommendation: ship B now, reconsider bundling when Phase 3.3 lands
