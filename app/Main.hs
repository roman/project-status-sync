module Main (main) where

import RIO

import CCS (version)
import CCS.Aggregate (AggregateResult (..), runAggregation)
import CCS.Event (EventSource (..), EventTag (..), SessionEvent (..), appendEvent)
import CCS.Filter (filterTranscriptFile)
import CCS.Process (ProcessConfig (..), processSession)
import RIO.Text qualified as T

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
  , acPromptFile :: !FilePath
  , acHandoffPrompt :: !FilePath
  , acProgressPrompt :: !FilePath
  , acSynthesisPrompt :: !FilePath
  , acBypassClaudeCheck :: !Bool
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
        config =
          ProcessConfig
            { pcOutputDir = acOutputDir
            , pcPromptFile = acPromptFile
            , pcHandoffPrompt = acHandoffPrompt
            , pcProgressPrompt = acProgressPrompt
            , pcSynthesisPrompt = acSynthesisPrompt
            , pcCommand = "claude"
            , pcCommandArgs = ["-p"]
            , pcBypassClaudeCheck = acBypassClaudeCheck
            }
      result <- runAggregation acSignalDir threshold (processSession config)
      case result of
        AggregatedSessions n ->
          logInfo $ "Processed " <> display n <> " session(s)"
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
    <*> option str (long "prompt-file" <> metavar "FILE" <> help "Path to extraction prompt file")
    <*> option str (long "handoff-prompt" <> metavar "FILE" <> help "Path to handoff generation prompt file")
    <*> option str (long "progress-prompt" <> metavar "FILE" <> help "Path to progress entry prompt file")
    <*> option str (long "synthesis-prompt" <> metavar "FILE" <> help "Path to status synthesis prompt file")
    <*> switch (long "bypass-claude-check" <> help "Strip CLAUDECODE env var from child processes (needed inside ralph loops)")

versionOpt :: Parser (a -> a)
versionOpt =
  infoOption
    (T.unpack version)
    (long "version" <> short 'V' <> help "Print version")
