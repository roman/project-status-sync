{-# LANGUAGE QuasiQuotes #-}

module Main (main) where

import RIO
import RIO.ByteString.Lazy qualified as LBS

import Data.Aeson (Value, decode, encode)
import Data.Aeson.QQ (aesonQQ)
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
