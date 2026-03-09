{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE NoImplicitPrelude #-}

module Prompts (
  extractionPrompt,
  handoffPrompt,
  progressPrompt,
  synthesisPrompt,
) where

import Data.FileEmbed (embedFile)
import RIO (ByteString)

extractionPrompt :: ByteString
extractionPrompt = $(embedFile "prompts/session-extraction.md")

handoffPrompt :: ByteString
handoffPrompt = $(embedFile "prompts/handoff-generation.md")

progressPrompt :: ByteString
progressPrompt = $(embedFile "prompts/progress-entry.md")

synthesisPrompt :: ByteString
synthesisPrompt = $(embedFile "prompts/status-synthesis.md")
