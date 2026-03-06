# Codify review learnings into skills and CLAUDE.md

**Date**: 2026-03-06
**Phase**: Supplementary (Haskell Development Skill + project config)

## What changed

After a code-critic review session, several corrections from the human were
identified as patterns worth codifying to reduce future supervision.

### Haskell development skill (`nix/packages/haskell-development-skill/SKILL.md`)

- **Parse-boundary filtering**: expanded "make illegal states unrepresentable"
  to include filtering invalid values at parse boundaries instead of wrapping
  fields in Maybe
- **Document design omissions**: when a type intentionally omits domain variants,
  document what is omitted and why
- **Test data readability**: prefer quasi-quoters for multi-line/escaped test data
  (e.g., aeson-qq for JSON)

### Project CLAUDE.md

- Added devenv `--impure` warning with the actual error message agents will see

### Global CLAUDE.md (zoo.nix, separate commit)

- "Understand before acting" rule: explain root cause before fixing bugs,
  read and name error causes before retrying commands

## Next

Commit the zoo.nix global CLAUDE.md change separately.
