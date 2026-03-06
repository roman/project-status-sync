module CCS.Filter (
  filterTranscript,
  filterTranscriptFile,
) where

import RIO
import RIO.ByteString.Lazy qualified as LBS
import RIO.Text qualified as T

import Data.Aeson (FromJSON (..), Value (..), withObject, (.:))
import Data.Aeson qualified as Aeson

-- | ACL type: raw Claude session JSONL entry.
-- Only fields we need for filtering; everything else is ignored.
data SessionEntry = SessionEntry
  { entryType :: !Text
  , entryContent :: !MessageContent
  }

data MessageContent
  = ContentString !Text
  | ContentArray ![ContentBlock]

newtype ContentBlock = ContentBlock
  { contentBlockText :: Text
  }

instance FromJSON SessionEntry where
  parseJSON = withObject "SessionEntry" $ \o ->
    SessionEntry
      <$> o
      .: "type"
      <*> (o .: "message" >>= (.: "content"))

instance FromJSON MessageContent where
  parseJSON (String t) = pure $ ContentString t
  parseJSON (Array arr) = ContentArray <$> mapM parseJSON (toList arr)
  parseJSON _ = pure $ ContentArray []

instance FromJSON ContentBlock where
  parseJSON = withObject "ContentBlock" $ \o -> do
    blockType <- o .: "type"
    if blockType == ("text" :: Text)
      then ContentBlock <$> o .: "text"
      else fail "not a text block"

-- | Filter a transcript JSONL bytestring to plain text with role labels.
-- Selects only user/assistant messages and extracts text content.
filterTranscript :: LBS.ByteString -> Text
filterTranscript =
  T.intercalate "\n"
    . mapMaybe formatEntry
    . mapMaybe Aeson.decode
    . LBS.split 0x0A

-- | Read and filter a transcript file.
filterTranscriptFile :: MonadIO m => FilePath -> m Text
filterTranscriptFile path = filterTranscript <$> liftIO (LBS.readFile path)

formatEntry :: SessionEntry -> Maybe Text
formatEntry SessionEntry{entryType, entryContent}
  | entryType == "user" || entryType == "assistant" =
      let
        texts = extractTexts entryContent
      in
        if null texts || all T.null texts
          then Nothing
          else Just $ T.toUpper entryType <> ":\n" <> T.intercalate "\n" texts <> "\n"
  | otherwise = Nothing

extractTexts :: MessageContent -> [Text]
extractTexts (ContentString t) = [t]
extractTexts (ContentArray blocks) = map contentBlockText blocks
