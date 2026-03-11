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

-- Data.Text: RIO.Text does not re-export breakOn/breakOnEnd
import Data.Text qualified as DT
import RIO.FilePath (makeRelative, takeFileName)
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

-- | Identify project from working directory.
-- Uses git remote + relative subpath for git repos,
-- falls back to directory name for non-git directories.
identifyProject
  :: (HasLogFunc env, MonadIO m, MonadReader env m)
  => FilePath
  -> m Project
identifyProject cwd = do
  mGitRoot <- gitCommand cwd ["rev-parse", "--show-toplevel"]
  case mGitRoot of
    Nothing -> pure $ directoryFallback cwd
    Just gitRoot -> do
      mRemote <- gitCommand cwd ["remote", "get-url", "origin"]
      case mRemote of
        Nothing -> pure $ directoryFallback cwd
        Just remoteUrl ->
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

directoryFallback :: FilePath -> Project
directoryFallback cwd =
  let
    name = T.pack $ takeFileName cwd
  in
    Project
      { projectKey = ProjectKey name
      , projectName = ProjectName name
      , projectPath = cwd
      }

newtype OrgMappings = OrgMappings (Map Text Text)
  deriving stock (Eq, Show)

newtype ProjectOverrides = ProjectOverrides (Map Text Text)
  deriving stock (Eq, Show)

deriveOutputSubpath :: ProjectKey -> OrgMappings -> ProjectOverrides -> FilePath
deriveOutputSubpath (ProjectKey key) (OrgMappings mappings) (ProjectOverrides overrides) =
  case Map.lookup key overrides of
    Just path -> T.unpack path
    Nothing -> case longestPrefixMatch key mappings of
      Just (prefix, replacement) ->
        let
          rest = T.drop (T.length prefix) key
          trimmed = fromMaybe rest (T.stripPrefix "/" rest)
        in
          if T.null trimmed
            then T.unpack (deriveName key)
            else T.unpack (replacement <> "/" <> trimmed)
      Nothing -> T.unpack (deriveName key)

longestPrefixMatch :: Text -> Map Text Text -> Maybe (Text, Text)
longestPrefixMatch key mappings =
  let
    candidates = filter (\(prefix, _) -> prefixMatches prefix key) (Map.toList mappings)
  in
    case candidates of
      [] -> Nothing
      (first : rest) ->
        let
          best = foldl' (\a b -> if T.length (fst a) >= T.length (fst b) then a else b) first rest
        in
          Just best

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
