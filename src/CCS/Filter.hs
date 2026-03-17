module CCS.Filter (
  filterTranscript,
  filterTranscriptFile,
  SessionEntry (..),
  MessageContent (..),
  ContentBlock (..),
  formatEntry,
  formatContent,
  formatBlock,
) where

import RIO
import RIO.ByteString.Lazy qualified as LBS
import RIO.Directory (doesFileExist)
import RIO.Text qualified as T

import Data.Aeson (FromJSON (..), Value (..), decode, withObject, (.:))
import Data.Aeson.Types (Parser)

-- | ACL type: raw Claude session JSONL entry.
-- Only fields we need for filtering; everything else is ignored.
data SessionEntry = SessionEntry
  { entryType :: !Text
  , entryContent :: !MessageContent
  }

-- | Message content relevant for LLM-readable transcript filtering.
-- Extracts text and thinking blocks. Non-readable blocks (tool_use,
-- tool_result, document, etc.) are intentionally unmodeled.
data MessageContent
  = ContentString !Text
  | ContentArray ![ContentBlock]

data ContentBlock
  = TextBlock !Text
  | ThinkingBlock !Text

instance FromJSON SessionEntry where
  parseJSON = withObject "SessionEntry" $ \o ->
    SessionEntry
      <$> o
      .: "type"
      <*> (o .: "message" >>= (.: "content"))

instance FromJSON MessageContent where
  parseJSON (String t) = pure $ ContentString t
  parseJSON (Array arr) = ContentArray . catMaybes <$> mapM parseContentBlock (toList arr)
  parseJSON _ = pure $ ContentArray []

parseContentBlock :: Value -> Parser (Maybe ContentBlock)
parseContentBlock = withObject "ContentBlock" $ \o -> do
  blockType <- o .: "type" :: Parser Text
  case blockType of
    "text" -> Just . TextBlock <$> o .: "text"
    "thinking" -> Just . ThinkingBlock <$> o .: "thinking"
    _ -> pure Nothing

-- | Filter a transcript JSONL bytestring to plain text with role labels.
-- Selects only user/assistant messages and extracts text and thinking content.
filterTranscript :: LBS.ByteString -> Text
filterTranscript =
  T.intercalate "\n"
    . mapMaybe formatEntry
    . mapMaybe decode
    . LBS.split 0x0A

-- | Read and filter a transcript file.
filterTranscriptFile :: MonadIO m => FilePath -> m Text
filterTranscriptFile path = do
  exists <- doesFileExist path
  if exists
    then filterTranscript <$> liftIO (LBS.readFile path)
    else pure ""

formatEntry :: SessionEntry -> Maybe Text
formatEntry SessionEntry{entryType, entryContent}
  | entryType == "user" || entryType == "assistant" =
      let
        segments = formatContent entryType entryContent
      in
        if null segments then Nothing else Just (T.intercalate "\n" segments)
  | otherwise = Nothing

formatContent :: Text -> MessageContent -> [Text]
formatContent role (ContentString t)
  | T.null t = []
  | otherwise = [T.toUpper role <> ":\n" <> t <> "\n"]
formatContent role (ContentArray blocks) =
  mapMaybe (formatBlock role) blocks

formatBlock :: Text -> ContentBlock -> Maybe Text
formatBlock role (TextBlock t)
  | T.null t = Nothing
  | otherwise = Just (T.toUpper role <> ":\n" <> t <> "\n")
formatBlock _ (ThinkingBlock t)
  | T.null t = Nothing
  | otherwise = Just ("THINKING:\n" <> t <> "\n")
