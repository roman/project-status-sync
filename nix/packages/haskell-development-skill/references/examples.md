# Haskell Development Examples

BAD/GOOD pairs for every convention in SKILL.md.

## Imports

```haskell
-- BAD
import Data.Text
import Data.Map
import Data.ByteString

-- GOOD
{-# LANGUAGE NoImplicitPrelude #-}
import RIO
import qualified RIO.Text as T
import qualified RIO.Map as Map
import qualified RIO.ByteString as B
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
-- The caller can inspect and handle these
lookupUser :: UserId -> RIO env (Maybe User)
parseConfig :: Text -> Either ConfigError Config

-- IO failures (disk, network, etc.): let them propagate as exceptions
-- Only catch at the business logic level when recovery is meaningful
loadConfig :: FilePath -> RIO env Config
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

## Testing: Validity Instances

```haskell
-- BAD: manual Arbitrary, no validity checking
instance Arbitrary User where
  arbitrary = User <$> arbitrary <*> arbitrary

-- GOOD: Validity + GenValid
data User = User
  { userName :: !Text
  , userAge  :: !Int
  }
  deriving (Show, Eq, Generic)

instance Validity User where
  validate u = mconcat
    [ declare "name is not empty" $ not $ T.null (userName u)
    , declare "age is non-negative" $ userAge u >= 0
    ]

instance GenValid User
-- Free generator + shrinking that respects validity constraints
```

## Testing: forAllValid

```haskell
-- BAD: raw arbitrary
testProperty "roundtrip" $
  \(user :: User) -> decode (encode user) === Just user

-- GOOD: validity-aware generation
testProperty "roundtrip" $
  forAllValid $ \(user :: User) ->
    decode (encode user) === Just user
```

## Testing: producesValid

```haskell
-- GOOD: assert function output is always valid
testProperty "normalize produces valid users" $
  producesValid (normalizeUser :: User -> User)

testProperty "merge produces valid stores" $
  producesValid2 (mergeStores :: Store -> Store -> Store)
```

## Testing: Structural GenValid (Simple Types)

```haskell
-- GOOD: no extra constraints, use structural helpers
instance GenValid ChangedFlag where
  genValid = genValidStructurallyWithoutExtraChecking
  shrinkValid = shrinkValidStructurallyWithoutExtraFiltering
```

## Testing: Custom GenValid (Complex Invariants)

Pattern from mergeful — types with disjoint sets or other constraints:

```haskell
instance GenValid (ClientStore ci si a) where
  genValid =
    (`suchThat` isValid) $ do
      ids <- genValid
      (s1, s2) <- splitSet ids
      clientStoreSynced <- mapWithIds s1
      clientStoreDeleted <- pure s2
      clientStoreAdded <- genValid
      pure ClientStore {..}
  shrinkValid = shrinkValidStructurally

-- Helpers
splitSet :: (Ord i) => Set i -> Gen (Set i, Set i)
splitSet s =
  if S.null s
    then pure (S.empty, S.empty)
    else do
      a <- elements $ S.toList s
      pure $ S.split a s

mapWithIds :: (Ord i, GenValid a) => Set i -> Gen (Map i a)
mapWithIds = fmap M.fromList . traverse (\i -> (,) i <$> genValid) . S.toList
```

## Testing: Nested forAllValid

```haskell
-- GOOD: multiple constrained generators
testProperty "sync handles modifications" $
  forAllValid $ \item ->
    forAllValid $ \serverTime ->
      forAllShrink
        (genValid `suchThat` (> serverTime))
        (filter (> serverTime) . shrinkValid)
        $ \serverTime' ->
          syncItem item serverTime serverTime' `shouldSatisfy` isValid
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

## Style: Point-Free

```haskell
-- BAD: unnecessary lambda/variable binding
getUserNames :: [User] -> [Text]
getUserNames users = map (\u -> userName u) users

-- GOOD: point-free
getUserNames :: [User] -> [Text]
getUserNames = map userName

-- BAD
processAll :: [Item] -> RIO env [Result]
processAll items = mapM processItem items

-- GOOD
processAll :: [Item] -> RIO env [Result]
processAll = mapM processItem
```
