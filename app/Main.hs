module Main (main) where

import CCS (version)

main :: IO ()
main = putStrLn $ "ccs version " <> version
