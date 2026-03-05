module Main (main) where

import RIO

import CCS (version)

main :: IO ()
main = runSimpleApp $ logInfo $ "ccs version " <> display version
