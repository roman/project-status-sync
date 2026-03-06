{-# LANGUAGE QuasiQuotes #-}
{-# OPTIONS_GHC -fno-warn-orphans #-}

module Main (main) where

import RIO
import RIO.ByteString.Lazy qualified as LBS
import RIO.Text qualified as T

import Data.Aeson (Value, decode, encode)
import Data.Aeson.QQ (aesonQQ)
import Test.QuickCheck
import Test.Tasty
import Test.Tasty.HUnit
import Test.Tasty.QuickCheck (testProperty)

import CCS.Filter (
  ContentBlock (..),
  MessageContent (..),
  SessionEntry (..),
  filterTranscript,
  formatBlock,
  formatContent,
  formatEntry,
 )
import CCS.Project (
  deriveName,
  normalizeRemoteUrl,
  stripDotGit,
 )
import CCS.Signal (SignalPayload (..))

main :: IO ()
main = defaultMain tests

tests :: TestTree
tests =
  testGroup
    "CCS"
    [ signalTests
    , projectTests
    , filterTests
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
    [ testGroup "normalizeRemoteUrl" normalizeRemoteUrlProps
    , testGroup "stripDotGit" stripDotGitProps
    , testGroup "deriveName" deriveNameProps
    , testGroup "Signal" signalProps
    , testGroup "Filter" filterProps
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
