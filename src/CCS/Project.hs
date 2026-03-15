module CCS.Project (
  ProjectKey (..),
  ProjectName (..),
  Project (..),
  OrgMappings (..),
  ProjectOverrides (..),
  identifyProject,
  normalizeRemoteUrl,
  stripDotGit,
  deriveName,
  deriveOutputSubpath,
) where

import RIO
import RIO.Map qualified as Map
import RIO.Text qualified as T

import Control.Monad.Trans.Maybe (MaybeT (..), runMaybeT)

-- Data.Text: RIO.Text does not re-export breakOn/breakOnEnd
import Data.Text qualified as DT
import RIO.FilePath (makeRelative)
import RIO.List (sortOn)
import System.Process.Typed (proc, readProcess)

newtype ProjectKey = ProjectKey Text
  deriving stock (Eq, Show)

newtype ProjectName = ProjectName Text
  deriving stock (Eq, Show)

data Project = Project
  { projectKey :: !ProjectKey
  , projectName :: !ProjectName
  , projectPath :: !FilePath
  }
  deriving stock (Eq, Show)

identifyProject
  :: (HasLogFunc env, MonadIO m, MonadReader env m)
  => FilePath
  -> m (Maybe Project)
identifyProject cwd =
  runMaybeT $ do
    gitRoot <- MaybeT $ gitCommand cwd ["rev-parse", "--show-toplevel"]
    remoteUrl <- MaybeT $ gitCommand cwd ["remote", "get-url", "origin"]
    pure $ gitProject (T.unpack gitRoot) remoteUrl cwd

gitProject :: FilePath -> Text -> FilePath -> Project
gitProject gitRoot remoteUrl cwd =
  let
    normalized = normalizeRemoteUrl remoteUrl
    subpath = deriveSubpath gitRoot cwd
    fullKey =
      if T.null subpath
        then normalized
        else normalized <> "/" <> subpath
    name = deriveName fullKey
  in
    Project
      { projectKey = ProjectKey fullKey
      , projectName = ProjectName name
      , projectPath = cwd
      }

-- | Normalize a git remote URL to canonical form: host/path
-- Handles SSH (git@host:path), ssh:// scheme, and HTTPS variants.
normalizeRemoteUrl :: Text -> Text
normalizeRemoteUrl url
  | Just rest <- T.stripPrefix "git@" url = normalizeScp rest
  | Just rest <- T.stripPrefix "ssh://" url = normalizeAfterScheme rest
  | Just rest <- T.stripPrefix "https://" url = normalizeAfterScheme rest
  | Just rest <- T.stripPrefix "http://" url = normalizeAfterScheme rest
  | otherwise = stripDotGit url

-- SCP-style: host:path.git → host/path (prefix already stripped)
normalizeScp :: Text -> Text
normalizeScp afterAt =
  let
    (host, colonPath) = DT.breakOn ":" afterAt
    path = T.drop 1 colonPath
  in
    host <> "/" <> stripDotGit path

-- Scheme-style: [user@]host/path.git → host/path (scheme already stripped)
normalizeAfterScheme :: Text -> Text
normalizeAfterScheme afterScheme =
  let
    afterUser = case DT.breakOn "@" afterScheme of
      (before, rest)
        | not (T.null rest) && not ("/" `T.isInfixOf` before) ->
            T.drop 1 rest
      _ -> afterScheme
    (host, slashPath) = DT.breakOn "/" afterUser
    path = T.drop 1 slashPath
  in
    host <> "/" <> stripDotGit path

stripDotGit :: Text -> Text
stripDotGit t = fromMaybe t (T.stripSuffix ".git" t)

deriveSubpath :: FilePath -> FilePath -> Text
deriveSubpath gitRoot cwd =
  let
    rel = makeRelative gitRoot cwd
  in
    if rel == "." || rel == cwd then "" else T.pack rel

deriveName :: Text -> Text
deriveName key =
  let
    (_, afterSlash) = DT.breakOnEnd "/" key
  in
    if T.null afterSlash then key else afterSlash

newtype OrgMappings = OrgMappings (Map Text Text)
  deriving stock (Eq, Show)

newtype ProjectOverrides = ProjectOverrides (Map Text Text)
  deriving stock (Eq, Show)

deriveOutputSubpath :: ProjectKey -> OrgMappings -> ProjectOverrides -> FilePath
deriveOutputSubpath (ProjectKey key) (OrgMappings mappings) (ProjectOverrides overrides) =
  T.unpack
    $ fromMaybe (deriveName key)
    $ Map.lookup key overrides
    <|> (applyOrgMapping key =<< longestPrefixMatch key mappings)

applyOrgMapping :: Text -> (Text, Text) -> Maybe Text
applyOrgMapping key (prefix, replacement) =
  let
    rest = T.drop (T.length prefix) key
    trimmed = fromMaybe rest (T.stripPrefix "/" rest)
  in
    if T.null trimmed then Nothing else Just (replacement <> "/" <> trimmed)

longestPrefixMatch :: Text -> Map Text Text -> Maybe (Text, Text)
longestPrefixMatch key mappings =
  listToMaybe
    . sortOn (Down . T.length . fst)
    . filter (\(prefix, _) -> prefixMatches prefix key)
    $ Map.toList mappings

prefixMatches :: Text -> Text -> Bool
prefixMatches prefix key =
  prefix == key || (prefix <> "/") `T.isPrefixOf` key

gitCommand
  :: (HasLogFunc env, MonadIO m, MonadReader env m)
  => FilePath
  -> [String]
  -> m (Maybe Text)
gitCommand dir args = do
  (exitCode, outBs, errBs) <- readProcess (proc "git" (["-C", dir] ++ args))
  let
    errout = T.decodeUtf8With T.lenientDecode (toStrictBytes errBs)
  case exitCode of
    ExitSuccess ->
      let
        out = T.decodeUtf8With T.lenientDecode (toStrictBytes outBs)
      in
        pure $ Just (T.strip out)
    ExitFailure _ -> do
      unless (T.null errout)
        $ logWarn
        $ "git "
        <> displayShow args
        <> " failed: "
        <> display errout
      pure Nothing
