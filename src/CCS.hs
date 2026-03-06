module CCS (
  version,
) where

import RIO

import Data.Version (showVersion)
import Paths_ccs qualified

version :: Text
version = fromString (showVersion Paths_ccs.version)
