module CCS.Signal
  ( SignalPayload(..)
  , readSignal
  , writeSignal
  ) where

import Data.Aeson (FromJSON(..), ToJSON(..), object, withObject, (.:), (.=))
import Data.Text (Text)

import qualified Data.Aeson as Aeson
import qualified Data.ByteString.Lazy as LBS

-- | On-disk JSON payload written by the SessionEnd hook.
-- This is the raw content of an @.available@ signal file.
data SignalPayload = SignalPayload
  { signalTranscriptPath :: Text
  , signalCwd            :: Text
  }
  deriving stock (Eq, Show)

instance ToJSON SignalPayload where
  toJSON sp = object
    [ "transcript_path" .= signalTranscriptPath sp
    , "cwd"             .= signalCwd sp
    ]

instance FromJSON SignalPayload where
  parseJSON = withObject "SignalPayload" $ \o ->
    SignalPayload
      <$> o .: "transcript_path"
      <*> o .: "cwd"

readSignal :: FilePath -> IO (Either String SignalPayload)
readSignal path = Aeson.eitherDecode <$> LBS.readFile path

writeSignal :: FilePath -> SignalPayload -> IO ()
writeSignal path = LBS.writeFile path . Aeson.encode
