module CCS.Aggregate (
  SessionId (..),
  AvailabilitySignal (..),
  AggregateResult (..),
  discoverSignals,
  isQuietPeriodElapsed,
  withLockFile,
  consumeSignal,
  runAggregation,
  checkSignals,
  checkQuietPeriod,
) where

import RIO
import RIO.Text qualified as T

import CCS.Signal (SignalPayload (..), readSignal)
import GHC.IO.Handle.Lock (LockMode (..), hTryLock)
import RIO.Directory (
  doesDirectoryExist,
  getModificationTime,
  listDirectory,
  removeFile,
 )
import RIO.FilePath (takeBaseName, takeExtension, (</>))
import RIO.List.Partial (maximum)
import RIO.Time (NominalDiffTime, UTCTime, diffUTCTime, getCurrentTime)

newtype SessionId = SessionId Text
  deriving stock (Eq, Ord, Show)

data AvailabilitySignal = AvailabilitySignal
  { asSessionId :: !SessionId
  , asProjectPath :: !FilePath
  , asTimestamp :: !UTCTime
  , asTranscriptPath :: !FilePath
  , asSignalPath :: !FilePath
  }
  deriving stock (Eq, Show)

data AggregateResult a
  = AggregatedSessions ![a]
  | QuietPeriodNotElapsed
  | NoSignalsFound
  | LockBusy
  deriving stock (Eq, Show)

discoverSignals :: HasLogFunc env => FilePath -> RIO env [AvailabilitySignal]
discoverSignals signalDir = do
  exists <- doesDirectoryExist signalDir
  if not exists
    then pure []
    else do
      entries <- listDirectory signalDir
      let
        availableFiles = filter (\f -> takeExtension f == ".available") entries
      catMaybes <$> mapM (parseSignalFile signalDir) availableFiles

parseSignalFile :: HasLogFunc env => FilePath -> FilePath -> RIO env (Maybe AvailabilitySignal)
parseSignalFile signalDir filename = do
  let
    fullPath = signalDir </> filename
    sessionId = SessionId (T.pack (takeBaseName filename))
  result <- readSignal fullPath
  case result of
    Left err -> do
      logWarn $ "Skipping malformed signal " <> fromString fullPath <> ": " <> fromString err
      pure Nothing
    Right payload -> do
      mtime <- getModificationTime fullPath
      pure
        $ Just
          AvailabilitySignal
            { asSessionId = sessionId
            , asProjectPath = T.unpack (signalCwd payload)
            , asTimestamp = mtime
            , asTranscriptPath = T.unpack (signalTranscriptPath payload)
            , asSignalPath = fullPath
            }

isQuietPeriodElapsed :: UTCTime -> NominalDiffTime -> [AvailabilitySignal] -> Bool
isQuietPeriodElapsed _ _ [] = True
isQuietPeriodElapsed now threshold signals =
  let
    -- SAFETY: maximum is partial on [], but the [] case is handled above
    newestTimestamp = maximum $ map asTimestamp signals
  in
    diffUTCTime now newestTimestamp >= threshold

withLockFile :: MonadUnliftIO m => FilePath -> m a -> m (Maybe a)
withLockFile lockPath action =
  bracket
    (liftIO $ openLock lockPath)
    (liftIO . closeLock)
    $ \case
      Nothing -> pure Nothing
      Just _ -> Just <$> action
 where
  openLock path = do
    h <- openFile path AppendMode
    acquired <- hTryLock h ExclusiveLock
    if acquired
      then pure (Just h)
      else do
        hClose h
        pure Nothing
  closeLock Nothing = pure ()
  closeLock (Just h) = hClose h

consumeSignal :: MonadIO m => AvailabilitySignal -> m ()
consumeSignal signal = liftIO $ removeFile (asSignalPath signal)

checkSignals :: [AvailabilitySignal] -> Either (AggregateResult a) [AvailabilitySignal]
checkSignals [] = Left NoSignalsFound
checkSignals ss = Right ss

checkQuietPeriod :: UTCTime -> NominalDiffTime -> [AvailabilitySignal] -> Either (AggregateResult a) [AvailabilitySignal]
checkQuietPeriod now threshold signals
  | isQuietPeriodElapsed now threshold signals = Right signals
  | otherwise = Left QuietPeriodNotElapsed

runAggregation
  :: (HasLogFunc env, Show a)
  => FilePath
  -> NominalDiffTime
  -> (AvailabilitySignal -> RIO env a)
  -> RIO env (AggregateResult a)
runAggregation signalDir quietMinutes processOne = do
  signals <- discoverSignals signalDir
  now <- liftIO getCurrentTime
  let
    gate = checkSignals signals >>= checkQuietPeriod now quietMinutes
  case gate of
    Left result -> do
      logDebug $ "Skipping aggregation: " <> displayShow result
      pure result
    Right readySignals ->
      acquireAndProcess readySignals
 where
  acquireAndProcess signals = do
    let
      lockPath = signalDir </> ".aggregate.lock"
    result <- withLockFile lockPath (processAll signals)
    case result of
      Nothing -> do
        logWarn "Lock busy, another aggregation is running"
        pure LockBusy
      Just results ->
        pure (AggregatedSessions results)

  processAll signals = do
    logInfo $ "Processing " <> display (length signals) <> " signal(s)"
    forM signals $ \signal -> do
      let
        SessionId sid = asSessionId signal
      logInfo $ "Processing session: " <> display sid
      result <- processOne signal
      consumeSignal signal
      pure result
