module CCS.Event (
  EventTag (..),
  EventSource (..),
  SessionEvent (..),
  appendEvent,
  appendJsonLine,
) where

import RIO

import Data.Aeson (FromJSON (..), ToJSON (..), object, withObject, (.:), (.=))
import Data.Aeson qualified as Aeson
import RIO.ByteString.Lazy qualified as LBS

newtype EventTag = EventTag Text
  deriving stock (Eq, Show)
  deriving newtype (FromJSON, ToJSON)

newtype EventSource = EventSource Text
  deriving stock (Eq, Show)
  deriving newtype (FromJSON, ToJSON)

data SessionEvent = SessionEvent
  { eventTag :: !EventTag
  , eventText :: !Text
  , eventSource :: !EventSource
  }
  deriving stock (Eq, Show)

instance ToJSON SessionEvent where
  toJSON SessionEvent{..} =
    object
      [ "tag" .= eventTag
      , "text" .= eventText
      , "source" .= eventSource
      ]

instance FromJSON SessionEvent where
  parseJSON = withObject "SessionEvent" $ \o ->
    SessionEvent
      <$> o
      .: "tag"
      <*> o
      .: "text"
      <*> o
      .: "source"

appendJsonLine :: (MonadIO m, ToJSON a) => FilePath -> a -> m ()
appendJsonLine path val = liftIO
  $ withBinaryFile path AppendMode
  $ \h ->
    LBS.hPut h (Aeson.encode val <> "\n")

appendEvent :: MonadIO m => FilePath -> SessionEvent -> m ()
appendEvent = appendJsonLine
