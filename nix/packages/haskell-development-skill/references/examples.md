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

