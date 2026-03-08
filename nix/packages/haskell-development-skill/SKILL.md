---
name: haskell-development-skill
description: >
  Haskell development conventions based on RIO. Use when working on
  Haskell source files (.hs, .cabal, .lhs). Covers imports, effect
  patterns, error handling, strictness, testing, and tooling.
---

# Haskell Development Conventions (RIO-based)

This skill applies to Haskell projects using the RIO prelude. Check for
`rio` in `build-depends` before applying these conventions.

All examples in `references/examples.md`. Each section below states the rule;
consult examples for BAD/GOOD code pairs.

## Module Organization

- Organize modules **vertically by domain** (e.g., `Syntax`, `Parsing`, `Infer`,
  `Evaluation`, `Pretty`) — never horizontally by language feature
- Never create `Types.hs`, `Constants.hs`, or `Utils.hs` modules
- Every module gets an **explicit export list** — no bare `module Foo where`
- Each module should be independently extractable into its own package
- Use a single `library` stanza in `.cabal` — executables, tests, and benchmarks
  are thin wrappers that import from the library

## Imports

- Enable `NoImplicitPrelude` in every module
- `import RIO` as the standard prelude (only exception to the explicit-import rule below)
- Every other import must be **qualified** or have an **explicit import list** —
  never use bare `import Foo`
- Prefer RIO re-exports over base/upstream modules: use `RIO.Text`, `RIO.ByteString`,
  `RIO.Map`, etc. Only import from upstream (e.g., `Data.Text.IO`) when the function
  is not available in the RIO module — add a comment above the import explaining why
- Qualified imports for data modules: `RIO.Text qualified as T`, `RIO.ByteString qualified as B`,
  `RIO.Map qualified as Map`, `RIO.Vector qualified as V`

## RIO-First Patterns

RIO is a **curated standard library**, not just a prelude. Always check what RIO
provides before reaching for upstream packages. Common traps:

### Safe alternatives to partial functions
- `maximum`/`minimum` → `maximumMaybe`/`minimumMaybe` from `RIO.List`
- `head`/`tail`/`last`/`init` → `headMaybe`/`tailMaybe`/`lastMaybe`/`initMaybe`
  from `RIO.List`
- `fromJust` → pattern match or `fromMaybe`
- `read` → `readMaybe` (re-exported by `RIO`)
- `!!` → `(!?)` from `RIO.Vector` or `lookup`/`find` patterns
- `foldl1`/`foldl1'`/`foldr1` → use `foldl'` with explicit seed, or switch
  to `NonEmpty` from `RIO.NonEmpty` and use its total `head`/`foldl1`
- If you must use a partial function, import from `RIO.List.Partial` or
  `RIO.Partial` explicitly — the `.Partial` suffix signals deliberate intent
- Any call to an unsafe/partial function (regardless of source) must have a
  `-- SAFETY:` comment at the usage site explaining why the call is safe

### Encoding and decoding (already in RIO.Text)
- `encodeUtf8`, `decodeUtf8With`, `decodeUtf8'`, `lenientDecode` are all
  re-exported by `RIO.Text` — never import `Data.Text.Encoding` directly

### Process execution (use RIO.Process)
- Never import `System.Process` — it uses `String` for stdin/stdout/stderr
- `RIO.Process` wraps `typed-process` with `ByteString` streams and logging
- Use `proc`, `readProcess`, `runProcess` from `RIO.Process` or
  `System.Process.Typed`
- `HasProcessContext env` provides PATH lookup, env vars, and working directory

### File I/O (use RIO.File, avoid lazy I/O)
- Never use `readFile` or `TIO.readFile` — they are lazy I/O
- Read text files: `readFileBinary path` then `T.decodeUtf8With T.lenientDecode`
- Write safely: `writeBinaryFileAtomic` (crash-safe) or
  `writeBinaryFileDurable` (fsync'd)
- `RIO` re-exports `readFileBinary`, `writeFileBinary` — no extra import needed

### Logging (display, not show)
- `display` for `Text`, `Int`, etc. — never `fromString . show`
- `displayShow` when you need a `Show` instance as `Utf8Builder`
- `displayBytesUtf8` for `ByteString` → `Utf8Builder`

### Containers and directories (RIO re-exports)
- `RIO.Map`, `RIO.Set`, `RIO.HashMap`, `RIO.HashSet`, `RIO.Seq`,
  `RIO.Vector`, `RIO.NonEmpty` — never import `Data.Map`, `Data.Set`, etc.
- `RIO.Directory` wraps `System.Directory` — never import it directly
- `RIO.FilePath` wraps `System.FilePath` — never import it directly
- `RIO.Time` wraps `Data.Time` — use it for `UTCTime`, `Day`,
  `NominalDiffTime`, `getCurrentTime`, `diffUTCTime`, etc.

### Concurrency and exceptions (already in RIO)
- `RIO` re-exports `UnliftIO.Exception` — never import `Control.Exception`
- `RIO` re-exports `UnliftIO.Async` — never import `Control.Concurrent.Async`
- `RIO` re-exports STM, MVar, IORef — never import from `Control.Concurrent`

## Effect Pattern

- Application code lives in `RIO env` (a `ReaderT env IO` newtype)
- Define `Has*` typeclasses with **lenses** (not plain getters) for each capability
- Use constraint-based signatures: `(HasConfig env, HasLogFunc env) => RIO env a`
- Never use the concrete env type in function signatures

## Data Types

- Strict fields by default: prefix every field with `!`
- One `App` record per application holding all capabilities
- Use `{-# UNPACK #-}` for simple fields (Int, Word, etc.)
- **Record syntax by default** for types with 3+ fields; positional is fine for
  newtypes and 1-2 field types where meaning is obvious from the type
- **Never use record syntax on sum types with different fields per constructor** —
  accessing a field defined on one constructor from another is a runtime crash.
  Extract the record into its own type instead
- **Smart constructors**: hide data constructors for API-boundary types, expose
  `mk*` functions and field accessors instead
- Provide a `.Internal` module for power users who need raw constructors
- **Compact vs non-compact strictness**: primitives (`Bool`, `Int`, `Text`, `Double`)
  and records of compact fields are compact — evaluate eagerly. Types containing
  lists or other recursive structures are non-compact — evaluate lazily
- **Consider evidence types** at API boundaries: when a `Bool` return could be
  misinterpreted, use a meaningful sum type or smart constructor instead
- **Never use Float/Double for quantities** (money, counts, scores): use `Int64`
  representing minimal units

## Safety

- No partial functions: never use `head`, `tail`, `fromJust`, `read`, `!!`,
  `maximum`, `minimum`, `foldl1` — they live in `RIO.Partial` /
  `RIO.List.Partial` for a reason. Use RIO's `*Maybe` safe alternatives
  (see RIO-First Patterns above)
- **No `foldl`**: always use `foldl'` (strict left fold) — lazy `foldl` causes
  space leaks
- No lazy I/O: use `readFileBinary` + decode, or conduit for streaming
- Always use `bracket`/`finally` for resource management
- **Beware ad-hoc polymorphism after refactoring**: prefer monomorphic functions
  where type dispatch could silently change behavior (e.g., `length` on a
  refactored container type)

## Error Handling

- `Maybe`/`Either` for expected failures the caller must handle
- `throwIO` for exceptional/bug cases
- No `ExceptT` in application-level monad stacks
- Define **custom exception types with context fields** — never throw bare strings
- Catch low-level exceptions and re-throw wrapped with high-level context
- Define `orDie` combinators for `Maybe`-to-`Either` conversion to reduce boilerplate
- Make illegal states unrepresentable: prefer `NonEmpty a -> a` over `[a] -> Maybe a`.
  Filter invalid values at the parse boundary so downstream code never sees them —
  don't wrap fields in `Maybe` to represent "might not exist"
- When a type intentionally omits variants from the domain (e.g., only modeling `text`
  blocks from a richer format), document what is omitted and why in a comment

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
- **Test data readability**: For multi-line or escaped test data, prefer quasi-quoters
  over string literals. Use domain-specific ones when available (e.g., `aeson-qq` for
  JSON, `raw-strings-qq` for raw text) — inline escaped strings are unreadable

## Tooling

- **Formatter**: fourmolu (`fourmolu --mode inplace src/**/*.hs`)
- **Linter**: hlint (`hlint src/`)

## GHC Flags

```
-Wall -Wcompat -Widentities -Wincomplete-record-updates
-Wincomplete-uni-patterns -Wpartial-fields -Wredundant-constraints
-Werror=missing-fields
```

## Recommended Extensions

`NoImplicitPrelude`, `OverloadedStrings`, `BangPatterns`,
`ScopedTypeVariables`, `LambdaCase`, `DerivingStrategies`,
`GeneralizedNewtypeDeriving`, `DeriveGeneric`, `FlexibleContexts`,
`FlexibleInstances`, `MultiParamTypeClasses`, `TupleSections`,
`TypeFamilies`, `RecordWildCards`, `NamedFieldPuns`

## Algebraic Design

- Derive `Semigroup`/`Monoid` from `Applicative` when applicable:
  `(<>) = liftA2 (<>)`, `mempty = pure mempty`, or `deriving via (Ap F a)`
- Use `foldMap` over `mapM` + manual combining
- Verify laws (associativity, identity) for custom instances — equational
  reasoning catches bugs that tests miss

## Style

- Prefer `let ... in` over `where` for bindings; `where` acceptable for
  local function definitions and small bindings
- `let` and `in` keywords live on their own lines
- `where` keyword lives on its own line
- Point-free when it improves clarity; named arguments when composition would
  obscure intent (avoid `((==) <*>)` style)
- Use `do` notation with `RecordWildCards` for record assembly instead of
  `<$>`/`<*>` chains (clearer error messages when fields change)
