module Main (main) where

import RIO
import RIO.ByteString.Lazy qualified as LBS

import Data.Aeson (decode, encode)
import Test.Tasty
import Test.Tasty.HUnit

import CCS.Filter (filterTranscript)
import CCS.Project (normalizeRemoteUrl)
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

filterTests :: TestTree
filterTests =
  testGroup
    "Filter"
    [ testCase "extracts user and assistant string content" $ do
        let
          input =
            LBS.intercalate
              "\n"
              [ "{\"type\":\"user\",\"message\":{\"content\":\"hello world\"}}"
              , "{\"type\":\"assistant\",\"message\":{\"content\":\"hi there\"}}"
              ]
        filterTranscript input @?= "USER:\nhello world\n\nASSISTANT:\nhi there\n"
    , testCase "extracts text from array content" $ do
        let
          input =
            "{\"type\":\"user\",\"message\":{\"content\":[{\"type\":\"text\",\"text\":\"first\"},{\"type\":\"text\",\"text\":\"second\"}]}}"
        filterTranscript input @?= "USER:\nfirst\nsecond\n"
    , testCase "skips non-text blocks in array" $ do
        let
          input =
            "{\"type\":\"assistant\",\"message\":{\"content\":[{\"type\":\"tool_use\",\"name\":\"Read\"},{\"type\":\"text\",\"text\":\"done\"}]}}"
        filterTranscript input @?= "ASSISTANT:\ndone\n"
    , testCase "skips non-user-assistant entries" $ do
        let
          input =
            LBS.intercalate
              "\n"
              [ "{\"type\":\"system\",\"message\":{\"content\":\"system prompt\"}}"
              , "{\"type\":\"user\",\"message\":{\"content\":\"real message\"}}"
              , "{\"type\":\"result\",\"content\":\"tool output\"}"
              ]
        filterTranscript input @?= "USER:\nreal message\n"
    , testCase "skips entries with empty content" $ do
        let
          input =
            LBS.intercalate
              "\n"
              [ "{\"type\":\"user\",\"message\":{\"content\":\"\"}}"
              , "{\"type\":\"assistant\",\"message\":{\"content\":\"actual reply\"}}"
              ]
        filterTranscript input @?= "ASSISTANT:\nactual reply\n"
    , testCase "empty input produces empty output"
        $ filterTranscript ""
        @?= ""
    ]
