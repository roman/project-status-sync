module CCS.Process (
  EventLogEntry (..),
  ProcessConfig (..),
  formatEventsCompact,
  formatEventsInput,
  generateStatusForProject,
  parseEventsJsonl,
  parseExtractionOutput,
  parseTopicSlug,
  processSession,
  runLLMPrompt,
  stripCodeFences,
  stripTopicLine,
) where

import RIO
import RIO.List (sort)
import RIO.Map qualified as Map
import RIO.Text qualified as T

-- Data.Text: RIO.Text does not re-export breakOn
import Data.Text qualified as DT

import CCS.Aggregate (AvailabilitySignal (..), SessionId (..))
import CCS.Event (EventSource (..), EventTag (..), SessionEvent (..), appendJsonLine)
import CCS.Filter (filterTranscriptFile)
import CCS.Project (OrgMappings (..), Project (..), ProjectKey (..), ProjectName (..), ProjectOverrides (..), deriveOutputSubpath, identifyProject)
import Data.Aeson (FromJSON (..), ToJSON (..), decodeStrict', object, withObject, (.:), (.=))
import RIO.ByteString qualified as BS

import RIO.Directory (createDirectoryIfMissing, doesDirectoryExist, doesFileExist, listDirectory)
import RIO.FilePath ((</>))
import RIO.Time (Day, UTCTime (..), getCurrentTime, utctDay)

-- System.Environment: RIO does not re-export getEnvironment
import System.Environment (getEnvironment)
import System.Process.Typed (byteStringInput, proc, readProcess, setEnv, setStdin)

data ProcessConfig = ProcessConfig
  { pcOutputDir :: !FilePath
  , pcExtractionPrompt :: !Text
  , pcHandoffPrompt :: !Text
  , pcProgressPrompt :: !Text
  , pcSynthesisPrompt :: !Text
  , pcCommand :: !FilePath
  , pcCommandArgs :: ![String]
  , pcBypassClaudeCheck :: !Bool
  , pcOrgMappings :: !OrgMappings
  , pcProjectOverrides :: !ProjectOverrides
  , pcFullResync :: !Bool
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
  parseLine line = do
    rest <- T.stripPrefix "[" (T.strip line)
    let
      (tag, afterBracket) = DT.breakOn "]" rest
    afterClose <- T.stripPrefix "]" afterBracket
    let
      text = T.strip afterClose
    guard (not (T.null tag) && not (T.null text))
    pure
      SessionEvent
        { eventTag = EventTag tag
        , eventText = text
        , eventSource = EventSource "conversation"
        }

formatEventsInput :: [SessionEvent] -> Text
formatEventsInput = T.unlines . map formatEvent
 where
  formatEvent SessionEvent{..} =
    let
      EventTag tag = eventTag
    in
      "[" <> tag <> "] " <> eventText

formatEventsCompact :: [EventLogEntry] -> Text
formatEventsCompact [] = ""
formatEventsCompact entries =
  let
    grouped =
      Map.toAscList
        $ foldl'
          (\m e -> Map.insertWith (flip (<>)) (eleDate e, eleSessionId e) [e] m)
          Map.empty
          entries
  in
    T.intercalate "\n" (map formatGroup grouped)
 where
  formatGroup ((day, SessionId sid), events) =
    let
      prefix = T.take 8 sid
      header = "## " <> T.pack (show day) <> " [" <> prefix <> "]"
    in
      header <> "\n\n" <> T.unlines (map formatBullet events)
  formatBullet EventLogEntry{eleEvent = SessionEvent{..}} =
    let
      EventTag tag = eventTag
    in
      "- [" <> tag <> "] " <> eventText

parseEventsJsonl :: ByteString -> [EventLogEntry]
parseEventsJsonl bs =
  mapMaybe decodeStrict' $ filter (not . BS.null) $ BS.split 0x0A bs

parseTopicSlug :: Text -> Maybe Text
parseTopicSlug =
  listToMaybe . mapMaybe extractTopic . T.lines
 where
  extractTopic line = do
    rest <- T.stripPrefix "TOPIC:" (T.strip line)
    let
      slug = T.strip rest
    guard (not (T.null slug))
    pure slug

runLLMPrompt
  :: HasLogFunc env
  => ProcessConfig
  -> Text
  -> Text
  -> RIO env (Maybe Text)
runLLMPrompt ProcessConfig{..} promptText inputText = do
  let
    fullInput = T.encodeUtf8 $ promptText <> "\n" <> inputText
    baseConfig =
      setStdin (byteStringInput (fromStrictBytes fullInput))
        $ proc pcCommand pcCommandArgs
  processConfig <-
    if pcBypassClaudeCheck
      then do
        env <- liftIO getEnvironment
        pure $ setEnv (filter ((/= "CLAUDECODE") . fst) env) baseConfig
      else pure baseConfig

  (exitCode, outBs, errBs) <- readProcess processConfig

  let
    out = T.decodeUtf8With T.lenientDecode (toStrictBytes outBs)
    err = T.decodeUtf8With T.lenientDecode (toStrictBytes errBs)

  case exitCode of
    ExitFailure code -> do
      logError $ "LLM command failed (exit " <> display code <> ")"
      unless (T.null err) $ logError $ "stderr: " <> display err
      pure Nothing
    ExitSuccess -> pure (Just (stripCodeFences out))

processSession
  :: HasLogFunc env
  => ProcessConfig
  -> AvailabilitySignal
  -> RIO env (Maybe Project)
processSession config@ProcessConfig{..} signal = do
  let
    SessionId sid = asSessionId signal

  mProject <- identifyProject (asProjectPath signal)
  case mProject of
    Nothing -> do
      logInfo $ "Skipping non-git session " <> display sid
      pure Nothing
    Just project -> do
      logInfo $ "Filtering transcript: " <> fromString (asTranscriptPath signal)
      filtered <- filterTranscriptFile (asTranscriptPath signal)

      if T.null filtered
        then do
          logWarn $ "Empty transcript after filtering for session " <> display sid
          pure (Just project)
        else do
          logInfo $ "Running extraction for session " <> display sid
          mOut <- runLLMPrompt config pcExtractionPrompt filtered

          withLLMResult logError mOut ("Extraction failed for session " <> display sid) $ \out -> do
            let
              events = parseExtractionOutput out
            logInfo $ "Extracted " <> display (length events) <> " event(s) for session " <> display sid

            now <- liftIO getCurrentTime

            let
              today = utctDay now
              mkEntry event =
                EventLogEntry
                  { eleDate = today
                  , eleSessionId = asSessionId signal
                  , eleProjectKey = projectKey project
                  , eleProjectName = projectName project
                  , eleEvent = event
                  }
              projectDir = pcOutputDir </> deriveOutputSubpath (projectKey project) pcOrgMappings pcProjectOverrides
              eventsFile = projectDir </> "EVENTS.jsonl"

            createDirectoryIfMissing True projectDir

            let
              entries = map mkEntry events
            mapM_ (appendJsonLine eventsFile) entries

            generateHandoff config signal events today projectDir
            generateProgressEntry config signal events now projectDir

          pure (Just project)

generateHandoff
  :: HasLogFunc env
  => ProcessConfig
  -> AvailabilitySignal
  -> [SessionEvent]
  -> Day
  -> FilePath
  -> RIO env ()
generateHandoff config signal events today projectDir = do
  let
    SessionId sid = asSessionId signal
  withEvents events ("handoff", sid) $ do
    let
      sessionPrefix = T.take 8 sid
      handoffDir = projectDir </> "handoffs"

    handoffExists <- doesDirectoryExist handoffDir
    handoffFiles <-
      if handoffExists
        then sort <$> listDirectory handoffDir
        else pure []

    let
      priorContext = case handoffFiles of
        [] -> ""
        fs ->
          "Previous handoffs in this project:\n"
            <> T.unlines (map (\f -> "- " <> T.pack f) fs)
            <> "\n"
      metadata =
        "Project session metadata:\n"
          <> "Date: "
          <> T.pack (show today)
          <> "\n"
          <> "Session: "
          <> sid
          <> "\n\n"
          <> priorContext
      eventsText = formatEventsInput events
      input = metadata <> eventsText

    logInfo $ "Running handoff generation for session " <> display sid
    mOut <- runLLMPrompt config (pcHandoffPrompt config) input
    withLLMResult logWarn mOut ("Handoff generation failed for session " <> display sid) $ \out -> do
      let
        topic = fromMaybe "session-work" (parseTopicSlug out)
        filename =
          T.unpack
            $ T.pack (show today)
            <> "-"
            <> sessionPrefix
            <> "-"
            <> topic
            <> ".md"
        handoffPath = handoffDir </> filename
        content = stripTopicLine out
        hasContent = not (T.null (T.strip content))

      when hasContent $ do
        createDirectoryIfMissing True handoffDir
        writeFileBinary handoffPath (T.encodeUtf8 content)
        logInfo $ "Wrote handoff: " <> fromString filename

generateProgressEntry
  :: HasLogFunc env
  => ProcessConfig
  -> AvailabilitySignal
  -> [SessionEvent]
  -> UTCTime
  -> FilePath
  -> RIO env ()
generateProgressEntry config signal events now projectDir = do
  let
    SessionId sid = asSessionId signal
  withEvents events ("progress", sid) $ do
    let
      sessionPrefix = T.take 8 sid
      metadata =
        "Session metadata:\n"
          <> "Date: "
          <> T.pack (show (utctDay now))
          <> "\n"
          <> "Session prefix: "
          <> sessionPrefix
          <> "\n\n"
      eventsText = formatEventsInput events
      input = metadata <> eventsText

    logInfo $ "Running progress entry for session " <> display sid
    mOut <- runLLMPrompt config (pcProgressPrompt config) input
    withLLMResult logWarn mOut ("Progress entry generation failed for session " <> display sid) $ \out -> do
      let
        entry = T.strip out
        progressFile = projectDir </> "progress.log"
      unless (T.null entry) $ do
        liftIO
          $ withBinaryFile progressFile AppendMode
          $ \h ->
            hPutBuilder h (getUtf8Builder (display entry <> "\n"))
        logInfo $ "Appended progress entry for session " <> display sid

generateStatusForProject
  :: HasLogFunc env
  => ProcessConfig
  -> Project
  -> RIO env ()
generateStatusForProject config@ProcessConfig{..} project = do
  let
    ProjectName pnameText = projectName project
    projectDir = pcOutputDir </> deriveOutputSubpath (projectKey project) pcOrgMappings pcProjectOverrides
    eventsFile = projectDir </> "EVENTS.jsonl"
    cursorFile = projectDir </> ".last-synthesized"
    statusPath = projectDir </> "STATUS.md"

  eventsBytes <- readFileBinary eventsFile
  let
    allEntries = parseEventsJsonl eventsBytes
    totalCount = length allEntries

  if null allEntries
    then logDebug $ "No events for synthesis, skipping project " <> display pnameText
    else do
      cursor <-
        if pcFullResync
          then do
            logInfo "Full resync requested, ignoring cursor"
            pure 0
          else do
            mCursor <- readCursor cursorFile totalCount
            case mCursor of
              Just n -> pure n
              Nothing -> do
                logWarn "Cursor missing or invalid, running full synthesis"
                pure 0

      if cursor >= totalCount && cursor > 0
        then logInfo $ "No new events for project " <> display pnameText <> " (cursor=" <> display cursor <> ", total=" <> display totalCount <> ")"
        else do
          let
            isIncremental = cursor > 0
            newEntries = drop cursor allEntries
            eventsToFormat = if isIncremental then newEntries else allEntries

          let
            handoffDir = projectDir </> "handoffs"
          handoffExists <- doesDirectoryExist handoffDir
          handoffFiles <-
            if handoffExists
              then sort <$> listDirectory handoffDir
              else pure []

          (previousStatus, effectiveEvents) <-
            if isIncremental
              then do
                existsStatus <- doesFileExist statusPath
                if existsStatus
                  then do
                    prev <- T.decodeUtf8With T.lenientDecode <$> readFileBinary statusPath
                    pure (prev, eventsToFormat)
                  else do
                    logWarn "STATUS.md missing during incremental synthesis, falling back to full"
                    pure ("", allEntries)
              else pure ("", eventsToFormat)

          let
            handoffList = case handoffFiles of
              [] -> "No handoff files yet.\n"
              fs ->
                "Recent handoff files:\n"
                  <> T.unlines (map (\f -> "- handoffs/" <> T.pack f) fs)
            previousSection =
              if T.null previousStatus
                then "## Previous STATUS.md\n\nNo previous status — generate from full history.\n"
                else "## Previous STATUS.md\n\n" <> previousStatus <> "\n"
            eventsSection = "## Events\n\n" <> formatEventsCompact effectiveEvents
            input =
              "Project: "
                <> pnameText
                <> "\n\n"
                <> handoffList
                <> "\n"
                <> previousSection
                <> "\n"
                <> eventsSection

          let
            inputLen = T.length input
          logInfo
            $ "Running "
            <> (if isIncremental then "incremental" else "full")
            <> " status synthesis for project "
            <> display pnameText
            <> " ("
            <> display inputLen
            <> " chars, "
            <> display (length effectiveEvents)
            <> " events)"
          mOut <- runLLMPrompt config pcSynthesisPrompt input
          withLLMResult logWarn mOut ("Status synthesis failed for project " <> display pnameText) $ \out -> do
            writeFileBinary statusPath (T.encodeUtf8 out)
            writeCursor cursorFile totalCount
            logInfo
              $ "Wrote STATUS.md for project "
              <> display pnameText
              <> " (cursor updated to "
              <> display totalCount
              <> ")"

readCursor :: MonadIO m => FilePath -> Int -> m (Maybe Int)
readCursor path totalEntries = do
  exists <- doesFileExist path
  if not exists
    then pure Nothing
    else do
      bs <- readFileBinary path
      let
        txt = T.strip $ T.decodeUtf8With T.lenientDecode bs
      case readMaybe (T.unpack txt) of
        Just n
          | n >= 0 && n <= totalEntries -> pure (Just n)
          | otherwise -> pure Nothing
        Nothing -> pure Nothing

writeCursor :: MonadIO m => FilePath -> Int -> m ()
writeCursor path count =
  writeFileBinary path (T.encodeUtf8 (T.pack (show count) <> "\n"))

withLLMResult :: (Utf8Builder -> RIO env ()) -> Maybe Text -> Utf8Builder -> (Text -> RIO env ()) -> RIO env ()
withLLMResult logLevel mOut failMsg onSuccess =
  case mOut of
    Nothing -> logLevel failMsg
    Just out -> onSuccess out

withEvents :: HasLogFunc env => [SessionEvent] -> (Text, Text) -> RIO env () -> RIO env ()
withEvents events (label, sid) action
  | null events = logDebug $ "No events for " <> display label <> ", skipping session " <> display sid
  | otherwise = action

stripTopicLine :: Text -> Text
stripTopicLine =
  T.unlines . filter (not . isTopicLine) . T.lines
 where
  isTopicLine line = "TOPIC:" `T.isPrefixOf` T.strip line

stripCodeFences :: Text -> Text
stripCodeFences input =
  let
    lns = T.lines input
  in
    case lns of
      (opening : rest)
        | "```" `T.isPrefixOf` T.strip opening ->
            case reverse rest of
              (closing : middle)
                | T.strip closing == "```" ->
                    T.unlines (reverse middle)
              _ -> input
      _ -> input
