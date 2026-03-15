module Main (main) where

import RIO

import CCS (version)
import CCS.Aggregate (AggregateResult (..), runAggregation)
import CCS.Event (EventSource (..), EventTag (..), SessionEvent (..), appendEvent)
import CCS.Filter (filterTranscriptFile)
import CCS.Process (ProcessConfig (..), generateStatusForProject, processSession)
import CCS.Project (OrgMappings (..), ProjectOverrides (..), dedup)
import Prompts qualified
import RIO.Map qualified as Map
import RIO.Text qualified as T

-- Data.Text: RIO.Text does not re-export breakOn
import Data.Text qualified as DT

import Options.Applicative (
  Mod,
  OptionFields,
  Parser,
  argument,
  auto,
  command,
  execParser,
  fullDesc,
  header,
  help,
  helper,
  info,
  infoOption,
  long,
  maybeReader,
  metavar,
  option,
  progDesc,
  short,
  str,
  subparser,
  switch,
  value,
  (<**>),
 )
import RIO.Time (secondsToNominalDiffTime)

-- System.Environment: RIO does not re-export lookupEnv
import System.Environment (lookupEnv)

data AggregateConfig = AggregateConfig
  { acSignalDir :: !FilePath
  , acQuietMinutes :: !Int
  , acOutputDir :: !FilePath
  , acExtractionPrompt :: !(Maybe FilePath)
  , acHandoffPrompt :: !(Maybe FilePath)
  , acProgressPrompt :: !(Maybe FilePath)
  , acSynthesisPrompt :: !(Maybe FilePath)
  , acLLMCommand :: !String
  , acLLMArgs :: ![String]
  , acBypassClaudeCheck :: !Bool
  , acOrgMappings :: !OrgMappings
  , acProjectOverrides :: !ProjectOverrides
  }

data Command
  = FilterCmd !FilePath
  | RecordEventCmd !EventTag !Text !EventSource
  | AggregateCmd !AggregateConfig

main :: IO ()
main = do
  cmd <- execParser opts
  runSimpleApp $ case cmd of
    FilterCmd path -> do
      result <- filterTranscriptFile path
      hPutBuilder stdout (getUtf8Builder (display result))
    RecordEventCmd tag txt source -> do
      mPath <- liftIO $ lookupEnv "SESSION_EVENTS_FILE"
      case mPath of
        Nothing -> do
          logError "SESSION_EVENTS_FILE not set"
          exitFailure
        Just path ->
          appendEvent path SessionEvent{eventTag = tag, eventText = txt, eventSource = source}
    AggregateCmd AggregateConfig{..} -> do
      let
        threshold = secondsToNominalDiffTime (fromIntegral acQuietMinutes * 60)
        llmArgs = if null acLLMArgs then ["-p"] else acLLMArgs
      extraction <- resolvePrompt acExtractionPrompt Prompts.extractionPrompt
      handoff <- resolvePrompt acHandoffPrompt Prompts.handoffPrompt
      progress <- resolvePrompt acProgressPrompt Prompts.progressPrompt
      synthesis <- resolvePrompt acSynthesisPrompt Prompts.synthesisPrompt
      let
        config =
          ProcessConfig
            { pcOutputDir = acOutputDir
            , pcExtractionPrompt = extraction
            , pcHandoffPrompt = handoff
            , pcProgressPrompt = progress
            , pcSynthesisPrompt = synthesis
            , pcCommand = acLLMCommand
            , pcCommandArgs = llmArgs
            , pcBypassClaudeCheck = acBypassClaudeCheck
            , pcOrgMappings = acOrgMappings
            , pcProjectOverrides = acProjectOverrides
            }
      result <- runAggregation acSignalDir threshold (processSession config)
      case result of
        AggregatedSessions touchedProjects -> do
          let
            uniqueProjects = dedup (catMaybes touchedProjects)
          logInfo $ "Processed " <> display (length touchedProjects) <> " session(s), " <> display (length uniqueProjects) <> " unique project(s)"
          forM_ uniqueProjects $ generateStatusForProject config
        QuietPeriodNotElapsed ->
          logInfo "Quiet period not yet elapsed, skipping"
        NoSignalsFound ->
          logInfo "No signals found"
        LockBusy ->
          logWarn "Another aggregation is already running"
 where
  opts =
    info
      (commandParser <**> helper <**> versionOpt)
      ( fullDesc
          <> header ("ccs - Claude Conversation Sync v" <> T.unpack version)
      )

commandParser :: Parser Command
commandParser =
  subparser
    ( command "filter" (info filterParser (progDesc "Filter JSONL transcript to plain text"))
        <> command "record-event" (info recordEventParser (progDesc "Record a session event to SESSION_EVENTS_FILE"))
        <> command "aggregate" (info aggregateParser (progDesc "Run aggregation job"))
    )

filterParser :: Parser Command
filterParser =
  FilterCmd
    <$> argument str (metavar "FILE" <> help "Path to JSONL transcript file")

recordEventParser :: Parser Command
recordEventParser =
  RecordEventCmd
    <$> fmap EventTag (textOption (long "tag" <> metavar "TAG" <> help "Event tag (decision, question, next, blocker, resolved, context, initiative)"))
    <*> textOption (long "text" <> metavar "TEXT" <> help "Event description")
    <*> fmap EventSource (textOption (long "source" <> metavar "SOURCE" <> value "conversation" <> help "Event source (default: conversation)"))

textOption :: Mod OptionFields String -> Parser Text
textOption = fmap T.pack . option str

aggregateParser :: Parser Command
aggregateParser =
  fmap AggregateCmd
    $ AggregateConfig
    <$> option str (long "signal-dir" <> metavar "DIR" <> help "Directory containing .available signal files")
    <*> option auto (long "quiet-minutes" <> metavar "N" <> value 20 <> help "Quiet period in minutes (default: 20)")
    <*> option str (long "output-dir" <> metavar "DIR" <> help "Output directory for EVENTS.jsonl")
    <*> optional (option str (long "extraction-prompt" <> metavar "FILE" <> help "Override extraction prompt (default: embedded)"))
    <*> optional (option str (long "handoff-prompt" <> metavar "FILE" <> help "Override handoff prompt (default: embedded)"))
    <*> optional (option str (long "progress-prompt" <> metavar "FILE" <> help "Override progress prompt (default: embedded)"))
    <*> optional (option str (long "synthesis-prompt" <> metavar "FILE" <> help "Override synthesis prompt (default: embedded)"))
    <*> option str (long "llm-command" <> metavar "CMD" <> value "claude" <> help "LLM command (default: claude)")
    <*> many (option str (long "llm-arg" <> metavar "ARG" <> help "LLM command argument (repeatable; default: -p)"))
    <*> switch (long "bypass-claude-check" <> help "Strip CLAUDECODE env var from child processes (needed inside ralph loops)")
    <*> fmap (OrgMappings . Map.fromList) (many (option (maybeReader parseKeyValue) (long "org-mapping" <> metavar "KEY=VALUE" <> help "Map git host/org prefix to name (repeatable)")))
    <*> fmap (ProjectOverrides . Map.fromList) (many (option (maybeReader parseKeyValue) (long "project-override" <> metavar "KEY=PATH" <> help "Override output subpath for project key (repeatable)")))

parseKeyValue :: String -> Maybe (Text, Text)
parseKeyValue s =
  let
    t = T.pack s
    (key, eqVal) = DT.breakOn "=" t
  in
    case T.uncons eqVal of
      Just ('=', val)
        | not (T.null key) && not (T.null val) -> Just (key, val)
      _ -> Nothing

resolvePrompt
  :: MonadIO m
  => Maybe FilePath
  -> ByteString
  -> m Text
resolvePrompt (Just path) _ = do
  bs <- liftIO $ readFileBinary path
  pure (T.decodeUtf8With T.lenientDecode bs)
resolvePrompt Nothing embedded =
  pure (T.decodeUtf8With T.lenientDecode embedded)

versionOpt :: Parser (a -> a)
versionOpt =
  infoOption
    (T.unpack version)
    (long "version" <> short 'V' <> help "Print version")
