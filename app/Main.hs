module Main (main) where

import RIO

import CCS (version)
import CCS.Event (EventSource (..), EventTag (..), SessionEvent (..), appendEvent)
import CCS.Filter (filterTranscriptFile)
import RIO.Text qualified as T

import Data.Text.IO qualified as TIO
import Options.Applicative (
  Mod,
  OptionFields,
  Parser,
  argument,
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
  value,
  (<**>),
 )

data Command
  = FilterCmd !FilePath
  | RecordEventCmd !EventTag !Text !EventSource
  | AggregateCmd

main :: IO ()
main = do
  cmd <- execParser opts
  runSimpleApp $ case cmd of
    FilterCmd path -> do
      result <- filterTranscriptFile path
      liftIO $ TIO.hPutStr stdout result
    RecordEventCmd tag txt source -> do
      mPath <- liftIO $ lookupEnv "SESSION_EVENTS_FILE"
      case mPath of
        Nothing -> do
          logError "SESSION_EVENTS_FILE not set"
          exitFailure
        Just path ->
          appendEvent path SessionEvent{eventTag = tag, eventText = txt, eventSource = source}
    AggregateCmd ->
      logInfo "aggregate: not yet implemented"
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
        <> command "aggregate" (info (pure AggregateCmd) (progDesc "Run aggregation job"))
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

versionOpt :: Parser (a -> a)
versionOpt =
  infoOption
    (T.unpack version)
    (long "version" <> short 'V' <> help "Print version")
