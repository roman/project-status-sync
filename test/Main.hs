{-# LANGUAGE QuasiQuotes #-}
{-# OPTIONS_GHC -fno-warn-orphans #-}

module Main (main) where

import RIO
import RIO.ByteString.Lazy qualified as LBS
import RIO.Directory (
  createDirectoryIfMissing,
  doesFileExist,
  getTemporaryDirectory,
  removeDirectoryRecursive,
  removeFile,
 )
import RIO.FilePath ((</>))
import RIO.Text qualified as T

-- System.IO: RIO does not re-export openBinaryTempFileWithDefaultPermissions
import System.IO (openBinaryTempFileWithDefaultPermissions)

-- System.Random: RIO does not provide random number generation
import System.Random (randomRIO)

import Data.Aeson (Value, decode, encode)
import Data.Aeson.QQ (aesonQQ)
import RIO.Map qualified as Map
import Test.QuickCheck
import Test.Tasty
import Test.Tasty.HUnit
import Test.Tasty.QuickCheck (testProperty)

import CCS.Aggregate (
  AggregateResult (..),
  AvailabilitySignal (..),
  SessionId (..),
  checkQuietPeriod,
  checkSignals,
  consumeSignal,
  discoverSignals,
  isQuietPeriodElapsed,
  runAggregation,
  withLockFile,
 )
import CCS.Event (
  EventSource (..),
  EventTag (..),
  SessionEvent (..),
  appendEvent,
 )
import CCS.Filter (
  ContentBlock (..),
  MessageContent (..),
  SessionEntry (..),
  filterTranscript,
  formatBlock,
  formatContent,
  formatEntry,
 )
import CCS.Process (
  EventLogEntry (..),
  formatEventsInput,
  parseExtractionOutput,
  parseTopicSlug,
  stripCodeFences,
  stripTopicLine,
 )
import CCS.Project (
  OrgMappings (..),
  Project (..),
  ProjectKey (..),
  ProjectName (..),
  ProjectOverrides (..),
  dedup,
  deriveName,
  deriveOutputSubpath,
  normalizeRemoteUrl,
  stripDotGit,
 )
import CCS.Signal (SignalPayload (..), writeSignal)
import RIO.List (nub)
import RIO.Time (NominalDiffTime, UTCTime (..), addUTCTime, fromGregorian, secondsToNominalDiffTime)

main :: IO ()
main = defaultMain tests

tests :: TestTree
tests =
  testGroup
    "CCS"
    [ signalTests
    , eventTests
    , projectTests
    , filterTests
    , aggregateTests
    , dedupTests
    , processTests
    , propertyTests
    ]

signalTests :: TestTree
signalTests =
  testGroup
    "Signal"
    [ testCase "JSON round-trip"
        $ let
            payload =
              SignalPayload
                { signalTranscriptPath = "/home/user/.claude/projects/abc/session.jsonl"
                , signalCwd = "/home/user/project"
                }
          in
            decode (encode payload) @?= Just payload
    , testCase "decodes expected JSON format"
        $ let
            json = "{\"transcript_path\":\"/tmp/session.jsonl\",\"cwd\":\"/tmp/proj\"}"
            expected =
              SignalPayload
                { signalTranscriptPath = "/tmp/session.jsonl"
                , signalCwd = "/tmp/proj"
                }
          in
            decode json @?= Just expected
    ]

eventTests :: TestTree
eventTests =
  testGroup
    "Event"
    [ testCase "JSON round-trip"
        $ let
            event =
              SessionEvent
                { eventTag = EventTag "decision"
                , eventText = "use launchd over systemd"
                , eventSource = EventSource "conversation"
                }
          in
            decode (encode event) @?= Just event
    , testCase "decodes expected JSON format"
        $ let
            json = "{\"tag\":\"blocker\",\"text\":\"waiting on API\",\"source\":\"conversation\"}"
            expected =
              SessionEvent
                { eventTag = EventTag "blocker"
                , eventText = "waiting on API"
                , eventSource = EventSource "conversation"
                }
          in
            decode json @?= Just expected
    , testCase "appendEvent writes JSONL line" $ do
        tmpDir <- getTemporaryDirectory
        (tmpPath, h) <- openBinaryTempFileWithDefaultPermissions tmpDir "events.jsonl"
        hClose h
        let
          event =
            SessionEvent
              { eventTag = EventTag "next"
              , eventText = "wire up hook"
              , eventSource = EventSource "conversation"
              }
        appendEvent tmpPath event
        contents <- LBS.readFile tmpPath
        removeFile tmpPath
        let
          decoded = decode contents
        fmap eventTag decoded @?= Just (EventTag "next")
        fmap eventText decoded @?= Just "wire up hook"
    , testCase "appendEvent appends multiple lines" $ do
        tmpDir <- getTemporaryDirectory
        (tmpPath, h) <- openBinaryTempFileWithDefaultPermissions tmpDir "events.jsonl"
        hClose h
        let
          event1 =
            SessionEvent
              { eventTag = EventTag "decision"
              , eventText = "first"
              , eventSource = EventSource "conversation"
              }
          event2 =
            SessionEvent
              { eventTag = EventTag "next"
              , eventText = "second"
              , eventSource = EventSource "conversation"
              }
        appendEvent tmpPath event1
        appendEvent tmpPath event2
        contents <- LBS.readFile tmpPath
        removeFile tmpPath
        let
          lineCount = length $ filter (not . LBS.null) $ LBS.split 0x0A contents
        lineCount @?= 2
    ]

noMappings :: OrgMappings
noMappings = OrgMappings Map.empty

noOverrides :: ProjectOverrides
noOverrides = ProjectOverrides Map.empty

projectTests :: TestTree
projectTests =
  testGroup
    "Project"
    [ testGroup
        "normalizeRemoteUrl"
        [ testCase "SSH SCP-style"
            $ normalizeRemoteUrl "git@github.com:user/repo.git"
            @?= "github.com/user/repo"
        , testCase "SSH SCP-style without .git"
            $ normalizeRemoteUrl "git@github.com:user/repo"
            @?= "github.com/user/repo"
        , testCase "HTTPS"
            $ normalizeRemoteUrl "https://github.com/user/repo.git"
            @?= "github.com/user/repo"
        , testCase "HTTPS without .git"
            $ normalizeRemoteUrl "https://github.com/user/repo"
            @?= "github.com/user/repo"
        , testCase "SSH scheme"
            $ normalizeRemoteUrl "ssh://git@github.com/user/repo.git"
            @?= "github.com/user/repo"
        , testCase "HTTP"
            $ normalizeRemoteUrl "http://github.com/user/repo.git"
            @?= "github.com/user/repo"
        , testCase "SSH and HTTPS produce same key"
            $ normalizeRemoteUrl "git@git.musta.ch:airbnb/kube-system.git"
            @?= normalizeRemoteUrl "https://git.musta.ch/airbnb/kube-system.git"
        , testCase "corporate git host"
            $ normalizeRemoteUrl "git@git.musta.ch:airbnb/ergo.git"
            @?= "git.musta.ch/airbnb/ergo"
        , testCase "HTTPS with token auth"
            $ normalizeRemoteUrl "https://token@github.com/user/repo.git"
            @?= "github.com/user/repo"
        ]
    , testGroup
        "deriveOutputSubpath"
        [ testCase "fallback to last path component"
            $ deriveOutputSubpath (ProjectKey "github.com/user/repo") noMappings noOverrides
            @?= "repo"
        , testCase "override takes priority over org mapping"
            $ let
                mappings = OrgMappings (Map.singleton "github.com/user" "User")
                overrides = ProjectOverrides (Map.singleton "github.com/user/repo" "Custom/path")
              in
                deriveOutputSubpath (ProjectKey "github.com/user/repo") mappings overrides
                  @?= "Custom/path"
        , testCase "org mapping produces org/repo path"
            $ let
                mappings = OrgMappings (Map.singleton "git.musta.ch/airbnb" "Airbnb")
              in
                deriveOutputSubpath (ProjectKey "git.musta.ch/airbnb/ergo") mappings noOverrides
                  @?= "Airbnb/ergo"
        , testCase "longest prefix match wins"
            $ let
                mappings =
                  OrgMappings
                    $ Map.fromList
                      [ ("git.musta.ch", "Corp")
                      , ("git.musta.ch/airbnb", "Airbnb")
                      ]
              in
                deriveOutputSubpath (ProjectKey "git.musta.ch/airbnb/ergo") mappings noOverrides
                  @?= "Airbnb/ergo"
        , testCase "shorter prefix used when longer doesn't match"
            $ let
                mappings =
                  OrgMappings
                    $ Map.fromList
                      [ ("git.musta.ch", "Corp")
                      , ("git.musta.ch/airbnb", "Airbnb")
                      ]
              in
                deriveOutputSubpath (ProjectKey "git.musta.ch/other/repo") mappings noOverrides
                  @?= "Corp/other/repo"
        , testCase "no matching prefix falls back to deriveName"
            $ let
                mappings = OrgMappings (Map.singleton "gitlab.com/org" "Org")
              in
                deriveOutputSubpath (ProjectKey "github.com/user/repo") mappings noOverrides
                  @?= "repo"
        , testCase "prefix must match at path boundary"
            $ let
                mappings = OrgMappings (Map.singleton "git.musta.ch/air" "Air")
              in
                deriveOutputSubpath (ProjectKey "git.musta.ch/airbnb/ergo") mappings noOverrides
                  @?= "ergo"
        , testCase "exact key match in override"
            $ let
                overrides = ProjectOverrides (Map.singleton "github.com/user/legacy" "Archived/legacy")
              in
                deriveOutputSubpath (ProjectKey "github.com/user/legacy") noMappings overrides
                  @?= "Archived/legacy"
        , testCase "key exactly equals org prefix falls back to deriveName"
            $ let
                mappings = OrgMappings (Map.singleton "github.com/org" "Org")
              in
                deriveOutputSubpath (ProjectKey "github.com/org") mappings noOverrides
                  @?= "org"
        ]
    ]

-- | Encode a JSON Value to the JSONL ByteString that filterTranscript expects.
jsonl :: [Value] -> LBS.ByteString
jsonl = LBS.intercalate "\n" . map encode

filterTests :: TestTree
filterTests =
  testGroup
    "Filter"
    [ testCase "extracts user and assistant string content" $ do
        let
          input =
            jsonl
              [ [aesonQQ| { "type": "user", "message": { "content": "hello world" } } |]
              , [aesonQQ| { "type": "assistant", "message": { "content": "hi there" } } |]
              ]
        filterTranscript input @?= "USER:\nhello world\n\nASSISTANT:\nhi there\n"
    , testCase "extracts text from array content" $ do
        let
          input =
            jsonl
              [ [aesonQQ| {
                    "type": "user",
                    "message": { "content": [
                      { "type": "text", "text": "first" },
                      { "type": "text", "text": "second" }
                    ] }
                  } |]
              ]
        filterTranscript input @?= "USER:\nfirst\n\nUSER:\nsecond\n"
    , testCase "extracts thinking block content" $ do
        let
          input =
            jsonl
              [ [aesonQQ| {
                    "type": "assistant",
                    "message": { "content": [
                      { "type": "thinking", "thinking": "let me reason", "signature": "abc" }
                    ] }
                  } |]
              ]
        filterTranscript input @?= "THINKING:\nlet me reason\n"
    , testCase "skips tool_use blocks" $ do
        let
          input =
            jsonl
              [ [aesonQQ| {
                    "type": "assistant",
                    "message": { "content": [
                      { "type": "tool_use", "id": "x", "name": "Read", "input": {} }
                    ] }
                  } |]
              ]
        filterTranscript input @?= ""
    , testCase "skips non-user-assistant entries" $ do
        let
          input =
            jsonl
              [ [aesonQQ| { "type": "queue-operation", "message": { "content": "queued" } } |]
              , [aesonQQ| { "type": "user", "message": { "content": "real message" } } |]
              ]
        filterTranscript input @?= "USER:\nreal message\n"
    , testCase "skips entries with empty content" $ do
        let
          input =
            jsonl
              [ [aesonQQ| { "type": "user", "message": { "content": "" } } |]
              , [aesonQQ| { "type": "assistant", "message": { "content": "actual reply" } } |]
              ]
        filterTranscript input @?= "ASSISTANT:\nactual reply\n"
    , testCase "empty input produces empty output"
        $ filterTranscript ""
        @?= ""
    ]

-- ---------------------------------------------------------------------------
-- Aggregate tests
-- ---------------------------------------------------------------------------

referenceTime :: UTCTime
referenceTime = UTCTime (fromGregorian 2026 3 6) 0

mkSignal :: Text -> UTCTime -> AvailabilitySignal
mkSignal sid ts =
  AvailabilitySignal
    { asSessionId = SessionId sid
    , asProjectPath = "/tmp/project"
    , asTimestamp = ts
    , asTranscriptPath = "/tmp/transcript.jsonl"
    , asSignalPath = "/tmp/signals/" <> T.unpack sid <> ".available"
    }

twentyMinutes :: NominalDiffTime
twentyMinutes = secondsToNominalDiffTime (20 * 60)

aggregateTests :: TestTree
aggregateTests =
  testGroup
    "Aggregate"
    [ testGroup
        "isQuietPeriodElapsed"
        [ testCase "empty signals → elapsed"
            $ isQuietPeriodElapsed referenceTime twentyMinutes []
            @?= True
        , testCase "signal older than threshold → elapsed"
            $ let
                old = addUTCTime (-1800) referenceTime
                signals = [mkSignal "s1" old]
              in
                isQuietPeriodElapsed referenceTime twentyMinutes signals @?= True
        , testCase "signal newer than threshold → not elapsed"
            $ let
                recent = addUTCTime (-300) referenceTime
                signals = [mkSignal "s1" recent]
              in
                isQuietPeriodElapsed referenceTime twentyMinutes signals @?= False
        , testCase "newest signal determines result"
            $ let
                old = addUTCTime (-3600) referenceTime
                recent = addUTCTime (-300) referenceTime
                signals = [mkSignal "s1" old, mkSignal "s2" recent]
              in
                isQuietPeriodElapsed referenceTime twentyMinutes signals @?= False
        ]
    , testGroup
        "discoverSignals"
        [ testCase "empty directory → no signals" $ do
            tmpDir <- getTemporaryDirectory
            (dir, cleanup) <- createTempSignalDir tmpDir
            signals <- runSimpleApp $ discoverSignals dir
            cleanup
            signals @?= []
        , testCase "finds .available files" $ do
            tmpDir <- getTemporaryDirectory
            (dir, cleanup) <- createTempSignalDir tmpDir
            let
              payload = SignalPayload "/tmp/t.jsonl" "/tmp/proj"
            writeSignal (dir </> "session-abc.available") payload
            signals <- runSimpleApp $ discoverSignals dir
            cleanup
            case signals of
              (s : _) -> asSessionId s @?= SessionId "session-abc"
              [] -> assertFailure "expected at least one signal"
        , testCase "ignores non-.available files" $ do
            tmpDir <- getTemporaryDirectory
            (dir, cleanup) <- createTempSignalDir tmpDir
            let
              payload = SignalPayload "/tmp/t.jsonl" "/tmp/proj"
            writeSignal (dir </> "session-abc.available") payload
            writeFileBinary (dir </> "other.txt") "not a signal"
            signals <- runSimpleApp $ discoverSignals dir
            cleanup
            length signals @?= 1
        ]
    , testGroup
        "withLockFile"
        [ testCase "returns Just on successful lock" $ do
            tmpDir <- getTemporaryDirectory
            let
              lockPath = tmpDir </> "test-lock-success"
            result <- runSimpleApp $ withLockFile lockPath (pure (42 :: Int))
            removeFile lockPath
            result @?= Just 42
        , testCase "lock is released after action" $ do
            tmpDir <- getTemporaryDirectory
            let
              lockPath = tmpDir </> "test-lock-released"
            _ <- runSimpleApp $ withLockFile lockPath (pure ())
            result <- runSimpleApp $ withLockFile lockPath (pure (99 :: Int))
            removeFile lockPath
            result @?= Just 99
        ]
    , testGroup
        "gate pipeline"
        [ testCase "checkSignals [] → Left NoSignalsFound"
            $ checkSignals []
            @?= (Left NoSignalsFound :: Either (AggregateResult ()) [AvailabilitySignal])
        , testCase "checkSignals [signal] → Right [signal]"
            $ let
                s = mkSignal "s1" referenceTime
              in
                checkSignals [s] @?= (Right [s] :: Either (AggregateResult ()) [AvailabilitySignal])
        , testCase "checkQuietPeriod with elapsed time → Right"
            $ let
                old = addUTCTime (-1800) referenceTime
                signals = [mkSignal "s1" old]
              in
                checkQuietPeriod referenceTime twentyMinutes signals
                  @?= (Right signals :: Either (AggregateResult ()) [AvailabilitySignal])
        , testCase "checkQuietPeriod with recent signal → Left"
            $ let
                recent = addUTCTime (-300) referenceTime
                signals = [mkSignal "s1" recent]
              in
                checkQuietPeriod referenceTime twentyMinutes signals
                  @?= (Left QuietPeriodNotElapsed :: Either (AggregateResult ()) [AvailabilitySignal])
        , testCase "composed: happy path passes through"
            $ let
                old = addUTCTime (-1800) referenceTime
                signals = [mkSignal "s1" old]
                result = checkSignals signals >>= checkQuietPeriod referenceTime twentyMinutes
              in
                result @?= (Right signals :: Either (AggregateResult ()) [AvailabilitySignal])
        , testCase "composed: empty input short-circuits"
            $ let
                result = checkSignals [] >>= checkQuietPeriod referenceTime twentyMinutes
              in
                result @?= (Left NoSignalsFound :: Either (AggregateResult ()) [AvailabilitySignal])
        ]
    , testGroup
        "runAggregation"
        [ testCase "returns NoSignalsFound for empty dir" $ do
            tmpDir <- getTemporaryDirectory
            (dir, cleanup) <- createTempSignalDir tmpDir
            result <- runSimpleApp $ runAggregation dir twentyMinutes (\_ -> pure (Nothing :: Maybe ()))
            cleanup
            result @?= NoSignalsFound
        , testCase "collects results from callback" $ do
            tmpDir <- getTemporaryDirectory
            (dir, cleanup) <- createTempSignalDir tmpDir
            let
              payload1 = SignalPayload "/tmp/t1.jsonl" "/tmp/proj"
              payload2 = SignalPayload "/tmp/t2.jsonl" "/tmp/proj"
            writeSignal (dir </> "session-aaa.available") payload1
            writeSignal (dir </> "session-bbb.available") payload2
            result <-
              runSimpleApp
                $ runAggregation dir (secondsToNominalDiffTime 0)
                $ \signal ->
                  let
                    SessionId sid = asSessionId signal
                  in
                    pure ("processed-" <> sid)
            cleanup
            case result of
              AggregatedSessions rs -> length rs @?= 2
              other -> assertFailure $ "expected AggregatedSessions, got: " <> show other
        ]
    , testGroup
        "consumeSignal"
        [ testCase "deletes signal file" $ do
            tmpDir <- getTemporaryDirectory
            let
              path = tmpDir </> "to-consume.available"
              payload = SignalPayload "/tmp/t.jsonl" "/tmp/proj"
            writeSignal path payload
            exists1 <- doesFileExist path
            exists1 @?= True
            let
              signal = mkSignal "to-consume" referenceTime
            consumeSignal signal{asSignalPath = path}
            exists2 <- doesFileExist path
            exists2 @?= False
        ]
    ]

createTempSignalDir :: FilePath -> IO (FilePath, IO ())
createTempSignalDir base = do
  n <- randomRIO (100000 :: Int, 999999)
  let
    dir = base </> "ccs-test-signals-" <> show n
  createDirectoryIfMissing True dir
  let
    cleanup = removeDirectoryRecursive dir
  pure (dir, cleanup)

-- ---------------------------------------------------------------------------
-- Dedup tests
-- ---------------------------------------------------------------------------

mkProject :: Text -> Text -> Project
mkProject key name =
  Project
    { projectKey = ProjectKey key
    , projectName = ProjectName name
    , projectPath = "/tmp/" <> T.unpack name
    }

dedupTests :: TestTree
dedupTests =
  testGroup
    "dedup"
    [ testCase "empty → empty"
        $ dedup []
        @?= []
    , testCase "different keys preserved"
        $ let
            p1 = mkProject "github.com/user/repo1" "repo1"
            p2 = mkProject "github.com/user/repo2" "repo2"
          in
            dedup [p1, p2] @?= [p1, p2]
    , testCase "same key deduplicates (first wins)"
        $ let
            p1 = mkProject "github.com/user/repo" "repo-original"
            p2 = mkProject "github.com/user/repo" "repo-duplicate"
          in
            dedup [p1, p2] @?= [p1]
    , testCase "duplicates interspersed"
        $ let
            p1 = mkProject "github.com/user/repo1" "repo1"
            p2 = mkProject "github.com/user/repo2" "repo2"
          in
            dedup [p1, p2, p1, p2] @?= [p1, p2]
    ]

-- ---------------------------------------------------------------------------
-- Process tests
-- ---------------------------------------------------------------------------

processTests :: TestTree
processTests =
  testGroup
    "Process"
    [ testGroup
        "parseExtractionOutput"
        [ testCase "parses valid event lines"
            $ let
                input = "[decision] chose X over Y\n[next] implement Z\n"
                events = parseExtractionOutput input
              in
                length events @?= 2
        , testCase "extracts tag and text"
            $ let
                events = parseExtractionOutput "[blocker] waiting on API\n"
              in
                case events of
                  [e] -> do
                    eventTag e @?= EventTag "blocker"
                    eventText e @?= "waiting on API"
                  _ -> assertFailure "expected exactly one event"
        , testCase "skips blank lines"
            $ let
                input = "[decision] chose X\n\n[next] do Y\n"
                events = parseExtractionOutput input
              in
                length events @?= 2
        , testCase "skips non-event lines"
            $ let
                input = "some random text\n[decision] real event\nmore noise\n"
                events = parseExtractionOutput input
              in
                length events @?= 1
        , testCase "handles empty input"
            $ parseExtractionOutput ""
            @?= []
        , testCase "sets source to conversation"
            $ let
                events = parseExtractionOutput "[context] some info\n"
              in
                case events of
                  [e] -> eventSource e @?= EventSource "conversation"
                  _ -> assertFailure "expected one event"
        , testCase "rejects empty tag"
            $ parseExtractionOutput "[] some text\n"
            @?= []
        , testCase "rejects empty text"
            $ parseExtractionOutput "[decision] \n"
            @?= []
        , testCase "handles leading whitespace"
            $ let
                events = parseExtractionOutput "  [next] trim me\n"
              in
                length events @?= 1
        ]
    , testGroup
        "EventLogEntry"
        [ testCase "JSON round-trip"
            $ let
                entry =
                  EventLogEntry
                    { eleDate = fromGregorian 2026 3 8
                    , eleSessionId = SessionId "abc123"
                    , eleProjectKey = ProjectKey "github.com/user/repo"
                    , eleProjectName = ProjectName "repo"
                    , eleEvent =
                        SessionEvent
                          { eventTag = EventTag "decision"
                          , eventText = "use X over Y"
                          , eventSource = EventSource "conversation"
                          }
                    }
              in
                decode (encode entry) @?= Just entry
        , testCase "matches expected JSON format"
            $ let
                entry =
                  EventLogEntry
                    { eleDate = fromGregorian 2026 2 27
                    , eleSessionId = SessionId "abc123"
                    , eleProjectKey = ProjectKey "git.musta.ch/airbnb/ergo"
                    , eleProjectName = ProjectName "ergo"
                    , eleEvent =
                        SessionEvent
                          { eventTag = EventTag "decision"
                          , eventText = "use launchd over systemd"
                          , eventSource = EventSource "conversation"
                          }
                    }
                decoded = decode (encode entry) :: Maybe Value
              in
                case decoded of
                  Just val -> do
                    let
                      expected =
                        [aesonQQ|
                        { "date": "2026-02-27"
                        , "session": "abc123"
                        , "project": "ergo"
                        , "project_key": "git.musta.ch/airbnb/ergo"
                        , "tag": "decision"
                        , "text": "use launchd over systemd"
                        , "source": "conversation"
                        }
                      |]
                    val @?= expected
                  Nothing -> assertFailure "failed to decode"
        ]
    , testGroup
        "parseTopicSlug"
        [ testCase "extracts slug from TOPIC: line"
            $ parseTopicSlug "some markdown\n\nTOPIC: auth-middleware\n"
            @?= Just "auth-middleware"
        , testCase "handles leading whitespace"
            $ parseTopicSlug "  TOPIC: my-topic  \n"
            @?= Just "my-topic"
        , testCase "returns Nothing when no TOPIC line"
            $ parseTopicSlug "just some text\nno topic here\n"
            @?= Nothing
        , testCase "returns Nothing for empty slug"
            $ parseTopicSlug "TOPIC: \n"
            @?= Nothing
        , testCase "takes first TOPIC line"
            $ parseTopicSlug "TOPIC: first\nTOPIC: second\n"
            @?= Just "first"
        ]
    , testGroup
        "formatEventsInput"
        [ testCase "formats events as bracketed lines"
            $ let
                events =
                  [ SessionEvent (EventTag "decision") "chose X" (EventSource "conversation")
                  , SessionEvent (EventTag "next") "do Y" (EventSource "conversation")
                  ]
              in
                formatEventsInput events @?= "[decision] chose X\n[next] do Y\n"
        , testCase "empty events produces empty output"
            $ formatEventsInput []
            @?= ""
        ]
    , testGroup
        "stripTopicLine"
        [ testCase "removes TOPIC: line from output"
            $ stripTopicLine "# Handoff\n\nSome content\n\nTOPIC: my-topic\n"
            @?= "# Handoff\n\nSome content\n\n"
        , testCase "preserves content when no TOPIC line"
            $ stripTopicLine "just text\nno topic\n"
            @?= "just text\nno topic\n"
        , testCase "handles TOPIC: with leading whitespace"
            $ stripTopicLine "content\n  TOPIC: slug\n"
            @?= "content\n"
        ]
    , testGroup
        "stripCodeFences"
        [ testCase "strips ```markdown wrapper"
            $ stripCodeFences "```markdown\n# Status\nAll good\n```\n"
            @?= "# Status\nAll good\n"
        , testCase "strips bare ``` wrapper"
            $ stripCodeFences "```\ncontent here\n```\n"
            @?= "content here\n"
        , testCase "preserves content without fences"
            $ stripCodeFences "just plain text\nno fences\n"
            @?= "just plain text\nno fences\n"
        , testCase "preserves content with only opening fence"
            $ stripCodeFences "```markdown\ncontent without closing\n"
            @?= "```markdown\ncontent without closing\n"
        , testCase "empty input unchanged"
            $ stripCodeFences ""
            @?= ""
        , testCase "strips ```md wrapper"
            $ stripCodeFences "```md\n# Title\n```\n"
            @?= "# Title\n"
        , testCase "handles no trailing newline on closing fence"
            $ stripCodeFences "```markdown\n# Status\n```"
            @?= "# Status\n"
        ]
    ]

-- ---------------------------------------------------------------------------
-- QuickCheck generators
-- ---------------------------------------------------------------------------

data UrlFormat = ScpStyle | SshScheme | HttpsScheme | HttpScheme
  deriving stock (Show, Eq, Enum, Bounded)

instance Arbitrary UrlFormat where
  arbitrary = elements [minBound .. maxBound]

genHostSegment :: Gen String
genHostSegment = resize 10 $ listOf1 (elements $ ['a' .. 'z'] ++ ['0' .. '9'])

genHost :: Gen Text
genHost = do
  segs <- resize 3 $ listOf1 genHostSegment
  pure $ T.intercalate "." (map T.pack segs)

genPathSegment :: Gen String
genPathSegment = resize 10 $ listOf1 (elements $ ['a' .. 'z'] ++ ['A' .. 'Z'] ++ ['0' .. '9'] ++ "-_")

genRepoPath :: Gen Text
genRepoPath = do
  segs <- resize 3 $ listOf1 genPathSegment
  pure $ T.intercalate "/" (map T.pack segs)

data GitUrl = GitUrl
  { guHost :: !Text
  , guPath :: !Text
  , guDotGit :: !Bool
  , guFormat :: !UrlFormat
  }
  deriving stock (Show)

instance Arbitrary GitUrl where
  arbitrary = do
    guHost <- genHost
    guPath <- genRepoPath
    guDotGit <- arbitrary
    guFormat <- arbitrary
    pure GitUrl{..}
  shrink GitUrl{..} =
    [GitUrl{guDotGit = d, ..} | d <- shrink guDotGit]
      ++ [GitUrl{guFormat = f, ..} | f <- shrink guFormat]

renderGitUrl :: GitUrl -> Text
renderGitUrl GitUrl{..} =
  let
    suffix = if guDotGit then ".git" else ""
    p = guPath <> suffix
  in
    case guFormat of
      ScpStyle -> "git@" <> guHost <> ":" <> p
      SshScheme -> "ssh://git@" <> guHost <> "/" <> p
      HttpsScheme -> "https://" <> guHost <> "/" <> p
      HttpScheme -> "http://" <> guHost <> "/" <> p

expectedNormalized :: GitUrl -> Text
expectedNormalized GitUrl{guHost, guPath} = guHost <> "/" <> guPath

genNonEmptyText :: Gen Text
genNonEmptyText = T.pack <$> listOf1 (elements $ ['a' .. 'z'] ++ ['0' .. '9'])

instance Arbitrary SignalPayload where
  arbitrary = do
    signalTranscriptPath <- genNonEmptyText
    signalCwd <- genNonEmptyText
    pure SignalPayload{..}

genRole :: Gen Text
genRole = elements ["user", "assistant"]

instance Arbitrary EventTag where
  arbitrary = EventTag <$> elements ["decision", "question", "next", "blocker", "resolved", "context", "initiative"]

instance Arbitrary EventSource where
  arbitrary = pure (EventSource "conversation")

instance Arbitrary SessionEvent where
  arbitrary = do
    eventTag <- arbitrary
    eventText <- genNonEmptyText
    eventSource <- arbitrary
    pure SessionEvent{..}

instance Arbitrary ProjectKey where
  arbitrary = ProjectKey <$> genNonEmptyText

instance Arbitrary ProjectName where
  arbitrary = ProjectName <$> genNonEmptyText

instance Arbitrary Project where
  arbitrary = do
    projectKey <- arbitrary
    projectName <- arbitrary
    projectPath <- T.unpack <$> genNonEmptyText
    pure Project{..}

instance Arbitrary ContentBlock where
  arbitrary =
    oneof
      [ TextBlock <$> genNonEmptyText
      , ThinkingBlock <$> genNonEmptyText
      ]

instance Arbitrary MessageContent where
  arbitrary =
    oneof
      [ ContentString <$> genNonEmptyText
      , ContentArray <$> listOf arbitrary
      ]

instance Arbitrary SessionEntry where
  arbitrary = do
    entryType <- genRole
    entryContent <- arbitrary
    pure SessionEntry{..}

-- ---------------------------------------------------------------------------
-- Property tests
-- ---------------------------------------------------------------------------

propertyTests :: TestTree
propertyTests =
  testGroup
    "Properties"
    [ testGroup "dedup" dedupProps
    , testGroup "normalizeRemoteUrl" normalizeRemoteUrlProps
    , testGroup "stripDotGit" stripDotGitProps
    , testGroup "deriveName" deriveNameProps
    , testGroup "Event" eventProps
    , testGroup "Signal" signalProps
    , testGroup "Filter" filterProps
    , testGroup "Process" processProps
    , testGroup "deriveOutputSubpath" deriveOutputSubpathProps
    ]

dedupProps :: [TestTree]
dedupProps =
  [ testProperty "result has no duplicate projectKeys" $ \(projects :: [Project]) ->
      let
        result = dedup projects
        keys = map projectKey result
      in
        nub keys === keys
  , testProperty "idempotent" $ \(projects :: [Project]) ->
      dedup projects === dedup (dedup projects)
  ]

normalizeRemoteUrlProps :: [TestTree]
normalizeRemoteUrlProps =
  [ testProperty "idempotent" $ \gu ->
      let
        url = renderGitUrl gu
        normalized = normalizeRemoteUrl url
      in
        normalizeRemoteUrl normalized === normalized
  , testProperty "format-independent" $ \gu ->
      let
        expected = expectedNormalized gu
        url = renderGitUrl gu
      in
        normalizeRemoteUrl url === expected
  ]

genWithOptionalDotGit :: Gen Text
genWithOptionalDotGit = do
  base <- genNonEmptyText
  suffix <- elements ["", ".git"]
  pure (base <> suffix)

stripDotGitProps :: [TestTree]
stripDotGitProps =
  [ testProperty "idempotent on single .git suffix"
      $ forAll genWithOptionalDotGit
      $ \txt ->
        stripDotGit (stripDotGit txt) === stripDotGit txt
  , testProperty "strips .git suffix"
      $ forAll genNonEmptyText
      $ \base ->
        stripDotGit (base <> ".git") === base
  , testProperty "preserves input without .git suffix"
      $ forAll genNonEmptyText
      $ \txt ->
        stripDotGit txt === txt
  ]

deriveNameProps :: [TestTree]
deriveNameProps =
  [ testProperty "non-empty for non-empty input"
      $ forAll genNonEmptyText
      $ \t ->
        not $ T.null (deriveName t)
  , testProperty "output never contains slash"
      $ forAll genNonEmptyText
      $ \t ->
        not $ T.isInfixOf "/" (deriveName (t <> "/" <> t))
  , testProperty "output is suffix of input"
      $ forAll genNonEmptyText
      $ \t ->
        T.isSuffixOf (deriveName t) t
  ]

eventProps :: [TestTree]
eventProps =
  [ testProperty "JSON round-trip" $ \event ->
      decode (encode (event :: SessionEvent)) === Just event
  ]

signalProps :: [TestTree]
signalProps =
  [ testProperty "JSON round-trip" $ \payload ->
      decode (encode (payload :: SignalPayload)) === Just payload
  ]

filterProps :: [TestTree]
filterProps =
  [ testProperty "formatEntry Nothing for non-user/assistant"
      $ forAll genNonEmptyText
      $ \role ->
        role /= "user" && role /= "assistant"
          ==> isNothing (formatEntry SessionEntry{entryType = role, entryContent = ContentString "x"})
  , testProperty "formatEntry Just for user/assistant with content"
      $ forAll genRole
      $ \role ->
        isJust (formatEntry SessionEntry{entryType = role, entryContent = ContentString "hello"})
  , testProperty "formatContent non-empty string produces non-empty list"
      $ forAll genRole
      $ \role ->
        forAll genNonEmptyText $ \txt ->
          not . null $ formatContent role (ContentString txt)
  , testProperty "formatBlock text preserves content"
      $ forAll genRole
      $ \role ->
        forAll genNonEmptyText $ \txt ->
          case formatBlock role (TextBlock txt) of
            Just result -> T.isInfixOf txt result
            Nothing -> False
  , testProperty "formatBlock thinking always labeled THINKING"
      $ forAll genNonEmptyText
      $ \txt ->
        case formatBlock "assistant" (ThinkingBlock txt) of
          Just result -> T.isPrefixOf "THINKING:" result
          Nothing -> False
  , testProperty "filterTranscript never crashes on arbitrary bytes" $ \bs ->
      let
        result = filterTranscript (LBS.pack bs)
      in
        T.length result `seq` True
  ]

deriveOutputSubpathProps :: [TestTree]
deriveOutputSubpathProps =
  [ testProperty "empty mappings falls back to deriveName"
      $ forAll genNonEmptyText
      $ \key ->
        deriveOutputSubpath (ProjectKey ("host/" <> key)) noMappings noOverrides
          === T.unpack (deriveName ("host/" <> key))
  , testProperty "override always wins over mapping"
      $ forAll genNonEmptyText
      $ \name ->
        let
          key = "github.com/org/" <> name
          overrides = ProjectOverrides (Map.singleton key ("Override/" <> name))
          mappings = OrgMappings (Map.singleton "github.com/org" "Mapped")
        in
          deriveOutputSubpath (ProjectKey key) mappings overrides
            === T.unpack ("Override/" <> name)
  ]

processProps :: [TestTree]
processProps =
  [ testProperty "parses well-formed [tag] text lines" $ \(event :: SessionEvent) ->
      let
        EventTag tag = eventTag event
        line = "[" <> tag <> "] " <> eventText event
        parsed = parseExtractionOutput line
      in
        length parsed === 1
  , testProperty "EventLogEntry JSON round-trip" $ \(event :: SessionEvent) ->
      let
        entry =
          EventLogEntry
            { eleDate = fromGregorian 2026 1 1
            , eleSessionId = SessionId "test-session"
            , eleProjectKey = ProjectKey "test/key"
            , eleProjectName = ProjectName "test"
            , eleEvent = event
            }
      in
        decode (encode entry) === Just entry
  ]
