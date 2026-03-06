module Main (main) where

import RIO

import Data.Aeson (decode, encode)
import Test.Tasty
import Test.Tasty.HUnit

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
