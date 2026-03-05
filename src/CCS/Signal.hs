module CCS.Signal (
  SignalPayload (..),
  readSignal,
  writeSignal,
) where

import RIO

import Data.Aeson (FromJSON (..), ToJSON (..), object, withObject, (.:), (.=))
import Data.Aeson qualified as Aeson
import RIO.ByteString.Lazy qualified as LBS

data SignalPayload = SignalPayload
  { signalTranscriptPath :: !Text
  , signalCwd :: !Text
  }
  deriving stock (Eq, Show)

instance ToJSON SignalPayload where
  toJSON SignalPayload{..} =
    object
      [ "transcript_path" .= signalTranscriptPath
      , "cwd" .= signalCwd
      ]

instance FromJSON SignalPayload where
  parseJSON = withObject "SignalPayload" $ \o ->
    SignalPayload
      <$> o
      .: "transcript_path"
      <*> o
      .: "cwd"

readSignal :: MonadIO m => FilePath -> m (Either String SignalPayload)
readSignal path = liftIO $ Aeson.eitherDecode <$> LBS.readFile path

writeSignal :: MonadIO m => FilePath -> SignalPayload -> m ()
writeSignal path = liftIO . LBS.writeFile path . Aeson.encode
