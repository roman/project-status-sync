module Main (main) where

import Test.Tasty
import Test.Tasty.HUnit

import CCS (version)

main :: IO ()
main = defaultMain tests

tests :: TestTree
tests = testGroup "CCS"
  [ testCase "version is set" $
      version @?= "0.1.0.0"
  ]
