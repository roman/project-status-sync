module Main (main) where

import RIO

import Data.Aeson (decode, encode)
import Test.Tasty
import Test.Tasty.HUnit

import CCS (version)
import CCS.Signal (SignalPayload (..))

main :: IO ()
main = defaultMain tests

tests :: TestTree
tests =
    testGroup
        "CCS"
        [ testCase "version is set"
            $ version
            @?= "0.1.0.0"
        , signalTests
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
