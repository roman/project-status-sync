# Haskell Development Examples

BAD/GOOD pairs for every convention in SKILL.md.

## Module Organization

```haskell
-- BAD: horizontal modules by language feature
module Types where        -- grabs everything
module Constants where    -- random values
module Utils where        -- junk drawer

-- GOOD: vertical modules by domain
module MyApp.Parsing (parseConfig, ParseError) where
module MyApp.Evaluation (eval, Value(..)) where
module MyApp.Pretty (render, Doc) where
```

## Export Lists

```haskell
-- BAD: bare module, everything exported
module MyApp.Config where

-- GOOD: explicit export list
module MyApp.Config
  ( Config
  , mkConfig
  , configHost
  , configPort
  ) where
```

## Smart Constructors

```haskell
-- BAD: exposed data constructor
module MyApp.Port (Port(..)) where

data Port = Port Int

-- GOOD: hidden constructor, smart constructor + accessor
module MyApp.Port (Port, mkPort, portNumber) where

data Port = Port !Int

mkPort :: Int -> Maybe Port
mkPort n
  | n > 0 && n <= 65535 = Just (Port n)
  | otherwise = Nothing

portNumber :: Port -> Int
portNumber (Port n) = n
```

## Single Library Stanza

```cabal
-- BAD: code duplicated across stanzas
executable my-app
  main-is: Main.hs
  other-modules: MyApp.Config, MyApp.Parsing, ...

test-suite my-tests
  other-modules: MyApp.Config, MyApp.Parsing, ...

-- GOOD: thin wrappers over library
library
  exposed-modules: MyApp.Config, MyApp.Parsing, MyApp.Main
  ...

executable my-app
  main-is: Main.hs
  build-depends: my-app

test-suite my-tests
  main-is: Main.hs
  build-depends: my-app
```

## Imports

```haskell
-- BAD: bare imports, no explicit list or qualification
import Data.Text
import Data.Map
import Options.Applicative

-- GOOD: RIO re-exports preferred, all imports qualified or with explicit lists
{-# LANGUAGE NoImplicitPrelude #-}
import RIO
import RIO.Text qualified as T
import RIO.Map qualified as Map
import RIO.ByteString qualified as B

-- GOOD: upstream import with comment when RIO doesn't re-export the function
-- Data.Text.IO: RIO.Text does not re-export hPutStr
import Data.Text.IO qualified as TIO

-- GOOD: explicit import list for non-data modules
import Options.Applicative (Parser, execParser, info, helper, subparser, command)
```

## RIO-First: Safe Alternatives to Partial Functions

```haskell
-- BAD: partial maximum from Data.List — crashes on []
import Data.List (maximum)
newest = maximum timestamps

-- BAD: foldl1' from Data.List — still partial on []
import Data.List (foldl1')
newest = foldl1' max timestamps

-- GOOD: maximumMaybe from RIO.List — total, returns Maybe
import RIO.List (maximumMaybe)
case maximumMaybe timestamps of
  Nothing -> handleEmpty
  Just newest -> use newest

-- GOOD: headMaybe from RIO.List — total
import RIO.List (headMaybe)
case headMaybe items of
  Nothing -> handleEmpty
  Just x -> use x

-- GOOD: use NonEmpty when you know the list is non-empty
import RIO.NonEmpty qualified as NE
processItems :: NonEmpty Item -> Result
processItems items =
  let newest = NE.head items  -- total on NonEmpty
  in ...

-- ACCEPTABLE: import from .Partial when a guard makes it safe
import RIO.List.Partial (maximum)
isQuietPeriodElapsed _ _ [] = True  -- [] handled here
isQuietPeriodElapsed now threshold signals =
  let
    -- SAFETY: [] case handled by clause above
    newestTimestamp = maximum $ map asTimestamp signals
  in ...
```

## RIO-First: Encoding and Decoding

```haskell
-- BAD: importing upstream encoding modules
import Data.Text.Encoding (encodeUtf8, decodeUtf8With)
import Data.Text.Encoding.Error (lenientDecode)

-- GOOD: already re-exported by RIO.Text
import RIO.Text qualified as T
decoded = T.decodeUtf8With T.lenientDecode rawBytes
encoded = T.encodeUtf8 myText
```

## RIO-First: Process Execution

```haskell
-- BAD: System.Process uses String for stdin/stdout/stderr
import System.Process (readProcessWithExitCode)
let input = T.unpack myText           -- Text → String (wasteful)
(exit, out, err) <- readProcessWithExitCode "cmd" args input
let result = T.pack out               -- String → Text (wasteful)

-- GOOD: typed-process via RIO.Process uses ByteString
import System.Process.Typed (proc, readProcess, setStdin, byteStringInput)
let
  input = T.encodeUtf8 myText
  config = setStdin (byteStringInput (fromStrictBytes input))
    $ proc "cmd" args
(exit, outBs, errBs) <- readProcess config
let result = T.decodeUtf8With T.lenientDecode (toStrictBytes outBs)
```

## RIO-First: File I/O

```haskell
-- BAD: lazy I/O via Data.Text.IO
import Data.Text.IO qualified as TIO
contents <- TIO.readFile path

-- BAD: lazy I/O via Prelude
contents <- readFile path

-- GOOD: strict binary read + decode (readFileBinary is from RIO)
bytes <- readFileBinary path
let contents = T.decodeUtf8With T.lenientDecode bytes

-- GOOD: atomic write (crash-safe)
import RIO.File (writeBinaryFileAtomic)
writeBinaryFileAtomic path (T.encodeUtf8 contents)
```

## RIO-First: Logging with display

```haskell
-- BAD: show + fromString for log messages
logInfo $ "Count: " <> fromString (show n)

-- GOOD: display for common types (Text, Int, etc.)
logInfo $ "Count: " <> display n

-- GOOD: displayShow when you need Show instance
logInfo $ "Config: " <> displayShow config

-- BAD: putStrLn for output
liftIO $ putStrLn ("Processing " ++ show item)

-- GOOD: structured logging
logInfo $ "Processing " <> display item
```

## RIO-First: Upstream Module Mapping

```haskell
-- BAD: importing upstream modules that RIO wraps
import Data.Map qualified as Map          -- use RIO.Map
import Data.Set qualified as Set          -- use RIO.Set
import Data.HashMap.Strict qualified as HM -- use RIO.HashMap
import Data.HashSet qualified as HS       -- use RIO.HashSet
import Data.Sequence qualified as Seq     -- use RIO.Seq
import Data.Vector qualified as V         -- use RIO.Vector
import System.Directory                   -- use RIO.Directory
import System.FilePath                    -- use RIO.FilePath
import Control.Exception                  -- already in RIO (via UnliftIO)
import Control.Concurrent.Async           -- already in RIO (via UnliftIO)
import Control.Concurrent.STM             -- already in RIO (via UnliftIO)
import Data.IORef                         -- already in RIO
import Control.Concurrent.MVar            -- already in RIO

-- GOOD: use RIO modules
import RIO.Map qualified as Map
import RIO.Set qualified as Set
import RIO.HashMap qualified as HM
import RIO.HashSet qualified as HS
import RIO.Seq qualified as Seq
import RIO.Vector qualified as V
import RIO.Directory (listDirectory, doesFileExist)
import RIO.FilePath ((</>), takeExtension)
-- Exception, Async, STM, IORef, MVar: already available from `import RIO`
```

## Effect Pattern: Has* Typeclasses

```haskell
-- BAD: plain getter
class HasConfig env where
  getConfig :: env -> Config

-- GOOD: lens for composability
class HasConfig env where
  configL :: Lens' env Config

-- Access:  view configL
-- Modify:  local (set configL newCfg) action
-- Compose: envL . configL
```

## Effect Pattern: Capability Constraints

```haskell
-- BAD: concrete env type
processFile :: FilePath -> RIO AppConfig Result

-- GOOD: capability constraints
processFile :: (HasConfig env, HasLogFunc env) => FilePath -> RIO env Result
```

## Data Types: Positional vs Record Syntax

```haskell
-- GOOD: positional for newtypes and small obvious types
newtype Name = Name Text
data Pair a b = Pair a b

-- GOOD: record syntax for 3+ fields
data Config = Config
  { configHost    :: !Text
  , configPort    :: !Int
  , configRetries :: !Int
  }

-- BAD: record syntax on sum type with different fields per constructor
-- accessing connHost on a Disconnected value is a runtime crash
data Connection
  = Connected { connHost :: !Text, connSocket :: !Socket }
  | Disconnected { discReason :: !Text }

-- GOOD: extract records, keep sum type positional
data ConnInfo = ConnInfo
  { connHost   :: !Text
  , connSocket :: !Socket
  }

data DiscInfo = DiscInfo
  { discReason :: !Text
  }

data Connection
  = Connected !ConnInfo
  | Disconnected !DiscInfo
```

## Data Types: Strict Fields

```haskell
-- BAD: lazy fields
data App = App
  { appLogFunc :: LogFunc
  , appConfig :: Config
  }

-- GOOD: strict fields
data App = App
  { appLogFunc :: !LogFunc
  , appConfig  :: !Config
  }
```

## Data Types: Never Weaken Strict Fields to Maybe

```haskell
-- BEFORE: strict field — compiler enforces every construction site provides a path
data ProcessConfig = ProcessConfig
  { pcOutputDir   :: !FilePath
  , pcPromptFile  :: !FilePath
  , pcCommand     :: !FilePath
  }

-- BAD: wrapping in Maybe "because callers can pass Nothing"
-- Moves the guarantee from compile-time to runtime. The compiler no longer
-- prevents constructing a ProcessConfig without a prompt path.
data ProcessConfig = ProcessConfig
  { pcOutputDir   :: !FilePath
  , pcPromptFile  :: !(Maybe FilePath)  -- was !FilePath
  , pcCommand     :: !FilePath
  }

-- If the field genuinely needs to become optional, that is a design change.
-- STOP and ask the user before proceeding.
```

## Safety: Partial Functions

```haskell
-- BAD
let x = head items
let y = fromJust mVal
let z = items !! 3

-- GOOD
case items of
  (x : _) -> use x
  [] -> handleEmpty

maybe handleNothing use mVal

case items ^? ix 3 of
  Just z -> use z
  Nothing -> handleMissing
```

## Data Types: Evidence Types at API Boundaries

```haskell
-- FINE for internal helpers and predicates
isPrime :: Int -> Bool

-- BETTER at API boundaries where callers could misinterpret:
-- evidence type ensures the value has been validated
newtype Prime = Prime Int
prime :: Int -> Maybe Prime
```

## Data Types: Quantities (Never Float)

```haskell
-- BAD: floating-point money
data Invoice = Invoice { total :: Double }

-- GOOD: Int64 minimal units
newtype Amount = Amount { unAmount :: Int64 }
  deriving (Show, Eq, Ord)

addAmount :: Amount -> Amount -> Amount
addAmount (Amount a) (Amount b) = Amount (a + b)
```

## Data Types: Compact vs Non-Compact Strictness

```haskell
-- Compact types: evaluate eagerly (strict folds, bang patterns)
data Point = Point
  { pointX :: {-# UNPACK #-} !Double
  , pointY :: {-# UNPACK #-} !Double
  }

-- Non-compact types: evaluate lazily (contains list)
data Result = Result
  { resultItems :: [Item]    -- no bang — lazy accumulation avoids quadratic
  , resultCount :: !Int      -- compact field — strict
  }
```

## Safety: Ad-Hoc Polymorphism Caution

```haskell
-- BAD: polymorphic length silently changes after refactoring
--   before: settingAllowList :: [Text]  → length = list length
--   after:  settingAllowList :: Set Text → length = ???
countAllowed = length (settingAllowList settings)

-- GOOD: monomorphic, explicit about the container
countAllowed = GHC.OldList.length (Set.toList (settingAllowList settings))
-- or better: Set.size (settingAllowList settings)
```

## Safety: No foldl

```haskell
-- BAD: lazy foldl causes thunk buildup / space leak
total = foldl (+) 0 items

-- GOOD: strict foldl'
total = foldl' (+) 0 items
```

## Safety: Resource Management

```haskell
-- BAD: manual cleanup
h <- openFile path ReadMode
contents <- B.hGetContents h
hClose h

-- GOOD: bracket
bracket (openFile path ReadMode) hClose $ \h ->
  B.hGetContents h
```

## Error Handling

```haskell
-- BAD: ExceptT in the app monad stack
runApp :: ExceptT AppError (ReaderT Config IO) ()

-- GOOD: RIO with clear error strategy
runApp :: RIO App ()

-- Detectable failures: return Maybe/Either
lookupUser :: UserId -> RIO env (Maybe User)
parseConfig :: Text -> Either ConfigError Config

-- IO failures: let them propagate as exceptions
loadConfig :: FilePath -> RIO env Config
```

## Error Handling: Custom Exception Types with Context

```haskell
-- BAD: bare string exception
throwIO (userError "Connection refused")

-- GOOD: custom exception with context fields
data ConnectException = ConnectException
  { ceHost :: !HostName
  , cePort :: !PortNumber
  , ceCause :: !IOException
  }
  deriving (Show, Typeable)

instance Exception ConnectException where
  displayException ConnectException{..} =
    "Failed to connect to " <> ceHost <> ":" <> show cePort
      <> ": " <> displayException ceCause

-- Catch and wrap low-level exceptions
connectTo host port =
  catch (rawConnect host port) $ \(e :: IOException) ->
    throwIO (ConnectException host port e)
```

## Error Handling: orDie Combinator

```haskell
-- BAD: nested case matching
case lookupHost name of
  Nothing -> Left "Host not found"
  Just host -> case lookupPort host of
    Nothing -> Left "Port not found"
    Just port -> Right (host, port)

-- GOOD: orDie flattens with Either do-notation
orDie :: Maybe a -> e -> Either e a
orDie (Just a) _ = Right a
orDie Nothing  e = Left e

resolve name = do
  host <- lookupHost name `orDie` "Host not found"
  port <- lookupPort host `orDie` "Port not found"
  pure (host, port)
```

## Error Handling: Make Illegal States Unrepresentable

```haskell
-- BAD: handle invalidity downstream
processItems :: [a] -> Maybe Result
processItems [] = Nothing
processItems xs = Just (compute xs)

-- GOOD: push validity upstream via types
processItems :: NonEmpty a -> Result
processItems xs = compute xs
```

## Error Handling: Result Types Over Nested Branches

```haskell
-- BAD: outcomes hidden in nested if/case control flow
runJob :: JobConfig -> RIO env ()
runJob config = do
  items <- fetchItems config
  case items of
    [] -> logDebug "Nothing to do"
    _ -> do
      ready <- checkReady config
      if not ready
        then logDebug "Not ready"
        else do
          locked <- acquireLock config
          if not locked
            then logWarn "Lock busy"
            else processItems items

-- GOOD: sum type enumerates all outcomes — compiler-checked, documented
data JobResult
  = JobProcessed !Int
  | JobNothingToDo
  | JobNotReady
  | JobLockBusy
  deriving stock (Eq, Show)

runJob :: JobConfig -> RIO env JobResult
runJob config = do
  items <- fetchItems config
  now <- getCurrentTime
  let
    gate = checkItems items >>= checkReady now config
  case gate of
    Left result -> pure result
    Right readyItems -> acquireAndProcess config readyItems
```

## Error Handling: Pure Gate Pipelines

```haskell
-- BAD: preconditions interleaved with IO, nested 3 levels deep
aggregate signalDir threshold process = do
  signals <- discover signalDir
  case signals of
    [] -> pure NoSignals
    _ -> do
      now <- getCurrentTime
      if not (isQuiet now threshold signals)
        then pure NotReady
        else do
          result <- withLock lockPath (mapM_ process signals)
          case result of
            Nothing -> pure LockBusy
            Just () -> pure (Done (length signals))

-- GOOD: pure gates composed with >>=, IO only on happy path
aggregate signalDir threshold process = do
  signals <- discover signalDir
  now <- getCurrentTime
  let
    gate = checkSignals signals >>= checkQuiet now threshold
  case gate of
    Left result -> pure result
    Right ready -> acquireAndProcess ready
 where
  checkSignals [] = Left NoSignals
  checkSignals ss = Right ss

  checkQuiet now thresh signals
    | isQuiet now thresh signals = Right signals
    | otherwise = Left NotReady

  acquireAndProcess signals = do
    result <- withLock lockPath (mapM_ process signals)
    pure $ case result of
      Nothing -> LockBusy
      Just () -> Done (length signals)
```

## Strings & Logging

```haskell
-- BAD: String + putStrLn
putStrLn ("Processing: " ++ show item)

-- GOOD: Text + structured logging
logInfo $ "Processing: " <> display item
```

## Concurrency

```haskell
-- BAD
myFork :: MonadBaseControl IO m => m () -> m ThreadId

-- GOOD
myFork :: MonadUnliftIO m => m () -> m ThreadId
```

## Library vs Application Code

```haskell
-- BAD: library locked to RIO
myParse :: Text -> RIO env Value

-- GOOD: library code with mtl constraints
myParse :: MonadIO m => Text -> m Value
```

## Testing: Property Tests with Tasty

```haskell
-- BAD: only unit tests
testCase "reverse reverses" $
  reverse [1, 2, 3] @?= [3, 2, 1]

-- GOOD: property tests with tasty-quickcheck
testProperty "reverse is involution" $
  \(xs :: [Int]) -> reverse (reverse xs) === xs
```

## Style: Declarative Over Imperative

```haskell
-- BAD: nested case trees
deriveOutput key mappings overrides =
  case Map.lookup key overrides of
    Just path -> T.unpack path
    Nothing -> case longestPrefixMatch key mappings of
      Just (prefix, replacement) ->
        let rest = T.drop (T.length prefix) key
        in T.unpack (replacement <> "/" <> rest)
      Nothing -> T.unpack (deriveName key)

-- GOOD: <|> chains with fromMaybe fallback
deriveOutput key mappings overrides =
  T.unpack $ fromMaybe (deriveName key) $
    Map.lookup key overrides
    <|> formatMatch <$> longestPrefixMatch key mappings
  where
    formatMatch (prefix, replacement) =
      let rest = T.drop (T.length prefix) key
      in replacement <> "/" <> rest

-- BAD: nested if-else
classify x =
  if x > 100
    then "high"
    else if x > 50
      then "medium"
      else "low"

-- GOOD: guards or find-based lookup
classify x
  | x > 100   = "high"
  | x > 50    = "medium"
  | otherwise  = "low"
```

## Style: let-in over where

```haskell
-- ACCEPTABLE for small functions
isAdult :: User -> Bool
isAdult u = userAge u >= threshold
  where
    threshold = 18

-- PREFERRED: let-in with let/in on their own lines
processUsers :: [User] -> RIO env [Result]
processUsers users =
  let
    validUsers = filter isValid users
    grouped = groupBy department validUsers
  in
    mapM processGroup grouped
```

## Style: Point-Free (When It Helps)

```haskell
-- BAD: unnecessary lambda/variable binding
getUserNames :: [User] -> [Text]
getUserNames users = map (\u -> userName u) users

-- GOOD: point-free improves clarity here
getUserNames :: [User] -> [Text]
getUserNames = map userName

-- BAD: point-free obscures intent
check :: Eq a => a -> a -> Bool
check = ((==) <*>)

-- GOOD: named arguments when composition is unclear
check :: Eq a => (a -> a) -> a -> Bool
check f x = x == f x
```

## Style: Record Assembly with do + RecordWildCards

```haskell
-- BAD: Applicative operators — silent breakage when fields reorder
mkUser :: Parser User
mkUser = User <$> nameField <*> ageField <*> emailField

-- GOOD: do notation with named fields — clear errors on field changes
mkUser :: Parser User
mkUser = do
  userName  <- nameField
  userAge   <- ageField
  userEmail <- emailField
  pure User{..}
```

## Style: Explaining Variables for Conditionals

```haskell
-- BAD: complex predicate inlined in conditional
unless (T.null (T.strip content)) $ do
  createDirectoryIfMissing True outDir
  writeFileBinary path (T.encodeUtf8 content)

-- GOOD: explaining variable names the intent
let
  hasContent = not (T.null (T.strip content))

when hasContent $ do
  createDirectoryIfMissing True outDir
  writeFileBinary path (T.encodeUtf8 content)

-- BAD: multi-part condition inlined
when (Map.member key cache && not (isExpired now (cache Map.! key))) $
  serve (cache Map.! key)

-- GOOD: named conditions, each self-documenting
let
  isCached = Map.member key cache
  isFresh = maybe False (not . isExpired now) (Map.lookup key cache)
  canServeFromCache = isCached && isFresh

when canServeFromCache $
  serve (cache Map.! key)
```

## Algebraic Design: Semigroup/Monoid from Applicative

```haskell
-- BAD: manual instance
instance Semigroup (Handler a) where
  Handler f <> Handler g = Handler (\x -> f x <> g x)

instance Monoid (Handler a) where
  mempty = Handler (const mempty)

-- GOOD: derive via Ap
newtype Handler a = Handler (Event -> a)
  deriving (Functor, Applicative)
  deriving (Semigroup, Monoid) via (Ap Handler a)

-- Use foldMap instead of mapM + combine
-- BAD
results <- mapM process inputs
pure (mconcat results)

-- GOOD
foldMap process inputs
```

## Algebraic Design: Verify Laws

```haskell
-- Verify monoid laws for custom instances via property tests
testProperty "associativity" $
  \(a, b, c :: MyType) ->
    (a <> b) <> c === a <> (b <> c)

testProperty "left identity" $
  \(a :: MyType) ->
    mempty <> a === a

testProperty "right identity" $
  \(a :: MyType) ->
    a <> mempty === a
```

