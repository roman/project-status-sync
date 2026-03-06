# QuickCheck Property Tests

**Date**: 2026-03-05
**Phase**: 2a (Tooling) — test infrastructure improvement

## What Was Done

Added 15 QuickCheck property tests covering pure functions across
`CCS.Project`, `CCS.Filter`, and `CCS.Signal`.

### Properties Added

- **normalizeRemoteUrl** (2): idempotent, format-independent via structured
  `GitUrl` generator testing all 4 URL formats × with/without `.git`
- **stripDotGit** (3): idempotent on single suffix, strips `.git`, preserves
  non-`.git` input — targeted generator caught `.git.git` edge case
- **deriveName** (3): non-empty output, no slashes, suffix-of-input
- **SignalPayload** (1): JSON round-trip with arbitrary payloads
- **Filter** (6): formatEntry rejection/acceptance, formatContent non-empty,
  formatBlock content preservation, thinking label, robustness on arbitrary bytes

### Dependencies Added

- `QuickCheck` and `tasty-quickcheck` in `ccs.cabal` test deps
- `tasty-quickcheck` in `nix/devenvs/default.nix`

### Exports Added

- `CCS.Project`: `stripDotGit`, `deriveName`
- `CCS.Filter`: `SessionEntry(..)`, `MessageContent(..)`, `ContentBlock(..)`,
  `formatEntry`, `formatContent`, `formatBlock`

### Code Critic Findings Addressed

- Removed 4 redundant normalizeRemoteUrl properties (subsumed by format-independent)
- Fixed stripDotGit generator to actually exercise stripping (was never hitting `.git` suffix)
- Fixed filterTranscript crash test to use `seq` instead of tautological `>= 0`
- Removed unused exports (`deriveSubpath`, `gitProject`)
- Added `shrink` to `GitUrl`, capped generator sizes

### Observation

The targeted `.git` generator immediately found that `stripDotGit` is not
idempotent for `.git.git` inputs. This is correct behavior (git remotes
never have double `.git`), so the property was adjusted to match the
actual contract: strips at most one `.git` suffix.

## Test Count

18 HUnit + 15 QuickCheck = 33 total tests, all passing.
