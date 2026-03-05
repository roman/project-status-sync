---
name: haskell-development-skill
description: >
  Haskell development conventions based on RIO. Use when working on
  Haskell source files (.hs, .cabal, .lhs). Covers imports, effect
  patterns, error handling, strictness, testing with genvalidity, and tooling.
---

# Haskell Development Conventions (RIO-based)

All examples in `references/examples.md`. Each section below states the rule;
consult examples for BAD/GOOD code pairs.

## Imports

- Enable `NoImplicitPrelude` in every module
- `import RIO` as the standard prelude
- Qualified imports for data modules: `RIO.Text as T`, `RIO.ByteString as B`,
  `RIO.Map as Map`, `RIO.Vector as V`

## Effect Pattern

- Application code lives in `RIO env` (a `ReaderT env IO` newtype)
- Define `Has*` typeclasses with **lenses** (not plain getters) for each capability
- Use constraint-based signatures: `(HasConfig env, HasLogFunc env) => RIO env a`
- Never use the concrete env type in function signatures

## Data Types

- Strict fields by default: prefix every field with `!`
- One `App` record per application holding all capabilities
- Use `{-# UNPACK #-}` for simple fields (Int, Word, etc.)

## Safety

- No partial functions: never use `head`, `tail`, `fromJust`, `read`, `!!`
  — they live in `RIO.Partial` for a reason
- No lazy I/O: use conduit for streaming
- Always use `bracket`/`finally` for resource management

## Error Handling

- `Maybe`/`Either` for expected failures the caller must handle
- `throwIO` for exceptional/bug cases
- No `ExceptT` in application-level monad stacks
- Define an app-wide exception type with `Exception` instance

## Strings & Logging

- `Text` for text, `ByteString` for binary — never `String`
- `logInfo`, `logDebug`, `logWarn`, `logError` — never `putStrLn`
- `Utf8Builder` for log message construction
- Enable `OverloadedStrings`

## Concurrency

- `MonadUnliftIO` — never `MonadBaseControl` or `MonadBase`
- Never use `MonadCatch` or `MonadMask` from exceptions package

## Library vs Application Code

- Application code: use `RIO env` directly for clearer errors
- Library code: generalize with `MonadIO`, `MonadReader env`, `MonadUnliftIO`,
  `MonadThrow`, `PrimMonad`

## Testing

- **Framework**: Tasty + tasty-hunit + tasty-quickcheck
- **Property testing**: QuickCheck via tasty-quickcheck
- **Validity testing**: genvalidity for domain types
  - Define `Validity` instances with `validate` and `declare`
  - Derive `GenValid` for free generators + validity-respecting shrinking
  - Use `forAllValid` instead of raw `forAll arbitrary`
  - Use `producesValid` / `producesValid2` to assert functions preserve validity
  - See mergeful/mergeless projects for real-world patterns

## Tooling

- **Formatter**: fourmolu (`fourmolu --mode inplace src/**/*.hs`)
- **Linter**: hlint (`hlint src/`)

## GHC Flags

```
-Wall -Wcompat -Widentities -Wincomplete-record-updates
-Wincomplete-uni-patterns -Wpartial-fields -Wredundant-constraints
```

## Recommended Extensions

`NoImplicitPrelude`, `OverloadedStrings`, `BangPatterns`,
`ScopedTypeVariables`, `LambdaCase`, `DerivingStrategies`,
`GeneralizedNewtypeDeriving`, `DeriveGeneric`, `FlexibleContexts`,
`FlexibleInstances`, `MultiParamTypeClasses`, `TupleSections`,
`TypeFamilies`, `RecordWildCards`, `NamedFieldPuns`

## Style

- Prefer `let ... in` over `where`; `where` acceptable only for small functions
- `let` and `in` keywords live on their own lines
- `where` keyword lives on its own line
- Prefer point-free style
