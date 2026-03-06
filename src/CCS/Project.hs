module CCS.Project (
  ProjectKey (..),
  ProjectName (..),
  Project (..),
  identifyProject,
  normalizeRemoteUrl,
) where

import Data.Text qualified as T
import RIO
import System.FilePath (makeRelative, takeFileName)
import System.Process (readProcessWithExitCode)

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
identifyProject :: MonadIO m => FilePath -> m Project
identifyProject cwd = liftIO $ do
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
    (host, colonPath) = T.breakOn ":" afterAt
    path = T.drop 1 colonPath
  in
    host <> "/" <> stripDotGit path

-- Scheme-style: [user@]host/path.git → host/path (scheme already stripped)
normalizeAfterScheme :: Text -> Text
normalizeAfterScheme afterScheme =
  let
    afterUser = case T.breakOn "@" afterScheme of
      (before, rest)
        | not (T.null rest) && not ("/" `T.isInfixOf` before) ->
            T.drop 1 rest
      _ -> afterScheme
    (host, slashPath) = T.breakOn "/" afterUser
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
    (_, afterSlash) = T.breakOnEnd "/" key
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

gitCommand :: FilePath -> [String] -> IO (Maybe Text)
gitCommand dir args = do
  (exitCode, stdout, _) <-
    readProcessWithExitCode "git" (["-C", dir] ++ args) ""
  pure $ case exitCode of
    ExitSuccess -> Just (T.strip $ T.pack stdout)
    ExitFailure _ -> Nothing
