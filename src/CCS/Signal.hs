module CCS.Signal (
  SignalPayload (..),
  readSignal,
  writeSignal,
) where

import RIO

import Data.Aeson (FromJSON (..), ToJSON (..), object, withObject, (.:), (.=))
import Data.Aeson qualified as Aeson
import RIO.ByteString qualified as BS
import RIO.ByteString.Lazy qualified as LBS
import RIO.Directory (renameFile)
import RIO.FilePath (takeDirectory)

-- System.IO: RIO does not re-export openBinaryTempFileWithDefaultPermissions
import System.IO (openBinaryTempFileWithDefaultPermissions)

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
readSignal path = do
  result <- liftIO $ tryIO (BS.readFile path)
  case result of
    Left e -> pure $ Left (displayException e)
    Right bs -> pure $ Aeson.eitherDecodeStrict' bs

writeSignal :: MonadIO m => FilePath -> SignalPayload -> m ()
writeSignal path payload = liftIO $ do
  let
    dir = takeDirectory path
  (tmpPath, h) <- openBinaryTempFileWithDefaultPermissions dir "signal.tmp"
  LBS.hPut h (Aeson.encode payload) `finally` hClose h
  renameFile tmpPath path
