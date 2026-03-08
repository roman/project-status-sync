module CCS.Process (
  EventLogEntry (..),
  ProcessConfig (..),
  parseExtractionOutput,
  processSession,
) where

import RIO
import RIO.Text qualified as T

-- Data.Text: RIO.Text does not re-export breakOn
import Data.Text qualified as DT

import CCS.Aggregate (AvailabilitySignal (..), SessionId (..))
import CCS.Event (EventSource (..), EventTag (..), SessionEvent (..), appendJsonLine)
import CCS.Filter (filterTranscriptFile)
import CCS.Project (Project (..), ProjectKey (..), ProjectName (..), identifyProject)
import Data.Aeson (FromJSON (..), ToJSON (..), object, withObject, (.:), (.=))

import Data.Time.Calendar (Day)
import Data.Time.Clock (getCurrentTime, utctDay)
import RIO.Directory (createDirectoryIfMissing)
import RIO.FilePath ((</>))
import System.Process.Typed (byteStringInput, proc, readProcess, setStdin)

data ProcessConfig = ProcessConfig
  { pcOutputDir :: !FilePath
  , pcPromptFile :: !FilePath
  , pcCommand :: !FilePath
  , pcCommandArgs :: ![String]
  }
  deriving stock (Show)

data EventLogEntry = EventLogEntry
  { eleDate :: !Day
  , eleSessionId :: !SessionId
  , eleProjectKey :: !ProjectKey
  , eleProjectName :: !ProjectName
  , eleEvent :: !SessionEvent
  }
  deriving stock (Eq, Show)

instance ToJSON EventLogEntry where
  toJSON EventLogEntry{..} =
    let
      SessionId sid = eleSessionId
      ProjectKey pk = eleProjectKey
      ProjectName pn = eleProjectName
    in
      object
        [ "date" .= eleDate
        , "session" .= sid
        , "project" .= pn
        , "project_key" .= pk
        , "tag" .= eventTag eleEvent
        , "text" .= eventText eleEvent
        , "source" .= eventSource eleEvent
        ]

instance FromJSON EventLogEntry where
  parseJSON = withObject "EventLogEntry" $ \o ->
    EventLogEntry
      <$> o
      .: "date"
      <*> fmap SessionId (o .: "session")
      <*> fmap ProjectKey (o .: "project_key")
      <*> fmap ProjectName (o .: "project")
      <*> ( SessionEvent
              <$> o
              .: "tag"
              <*> o
              .: "text"
              <*> o
              .: "source"
          )

parseExtractionOutput :: Text -> [SessionEvent]
parseExtractionOutput =
  mapMaybe parseLine . T.lines
 where
  parseLine line =
    let
      trimmed = T.strip line
    in
      case T.uncons trimmed of
        Just ('[', rest) ->
          case DT.breakOn "]" rest of
            (tag, afterBracket)
              | not (T.null afterBracket) ->
                  let
                    text = T.strip (T.drop 1 afterBracket)
                  in
                    if T.null tag || T.null text
                      then Nothing
                      else
                        Just
                          SessionEvent
                            { eventTag = EventTag tag
                            , eventText = text
                            , eventSource = EventSource "conversation"
                            }
            _ -> Nothing
        _ -> Nothing

processSession
  :: HasLogFunc env
  => ProcessConfig
  -> AvailabilitySignal
  -> RIO env ()
processSession ProcessConfig{..} signal = do
  let
    SessionId sid = asSessionId signal

  logInfo $ "Filtering transcript: " <> fromString (asTranscriptPath signal)
  filtered <- filterTranscriptFile (asTranscriptPath signal)

  if T.null filtered
    then logWarn $ "Empty transcript after filtering for session " <> display sid
    else do
      promptBytes <- readFileBinary pcPromptFile
      let
        promptText = T.decodeUtf8With T.lenientDecode promptBytes
        fullPrompt = T.encodeUtf8 $ promptText <> "\n" <> filtered
        processConfig =
          setStdin (byteStringInput (fromStrictBytes fullPrompt))
            $ proc pcCommand pcCommandArgs

      logInfo $ "Running extraction for session " <> display sid
      (exitCode, outBs, errBs) <- readProcess processConfig

      let
        out = T.decodeUtf8With T.lenientDecode (toStrictBytes outBs)
        err = T.decodeUtf8With T.lenientDecode (toStrictBytes errBs)

      case exitCode of
        ExitFailure code -> do
          logError
            $ "Extraction command failed (exit "
            <> display code
            <> ") for session "
            <> display sid
          unless (T.null err)
            $ logError
            $ "stderr: "
            <> display err
        ExitSuccess -> do
          let
            events = parseExtractionOutput out
          logInfo $ "Extracted " <> display (length events) <> " event(s) for session " <> display sid

          project <- identifyProject (asProjectPath signal)

          today <- liftIO $ utctDay <$> getCurrentTime
          let
            mkEntry day proj event =
              EventLogEntry
                { eleDate = day
                , eleSessionId = asSessionId signal
                , eleProjectKey = projectKey proj
                , eleProjectName = projectName proj
                , eleEvent = event
                }
            ProjectName pname = projectName project
            eventsDir = pcOutputDir </> T.unpack pname
            eventsFile = eventsDir </> "EVENTS.jsonl"

          createDirectoryIfMissing True eventsDir

          let
            entries = map (mkEntry today project) events
          mapM_ (appendJsonLine eventsFile) entries
