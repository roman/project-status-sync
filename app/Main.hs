module Main (main) where

import RIO

import CCS (version)
import CCS.Filter (filterTranscriptFile)
import Data.Text qualified as T
import Data.Text.IO qualified as TIO
import Options.Applicative

data Command
  = FilterCmd !FilePath
  | AggregateCmd

main :: IO ()
main = do
  cmd <- execParser opts
  runSimpleApp $ case cmd of
    FilterCmd path -> do
      result <- filterTranscriptFile path
      liftIO $ TIO.hPutStr stdout result
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
        <> command "aggregate" (info (pure AggregateCmd) (progDesc "Run aggregation job"))
    )

filterParser :: Parser Command
filterParser =
  FilterCmd
    <$> argument str (metavar "FILE" <> help "Path to JSONL transcript file")

versionOpt :: Parser (a -> a)
versionOpt =
  infoOption
    (T.unpack version)
    (long "version" <> short 'V' <> help "Print version")
