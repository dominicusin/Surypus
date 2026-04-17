module System.Logger where

import Control.Concurrent.STM (TVar, newTVarIO, readTVar, writeTVar)
import Data.Text (Text)
import Data.Time.Clock (UTCTime, getCurrentTime)
import qualified System.IO as IO

-- | Log levels
data LogLevel = Debug | Info | Warn | Error | Critical
  deriving (Show, Eq, Ord)

-- | Log entry
data LogEntry = LogEntry
  { logTimestamp :: UTCTime,
    logLevel :: LogLevel,
    logSource :: Text,
    logMessage :: Text,
    logContext :: [(Text, Text)]
  }

-- | Logger state
newtype Logger = Logger (TVar [LogEntry])

-- | Initialize logger
initLogger :: IO Logger
initLogger = Logger <$> newTVarIO []

-- | Log a message
logMessage :: Logger -> LogLevel -> Text -> [(Text, Text)] -> IO ()
logMessage logger level source msg context = do
  entry <- LogEntry <$> getCurrentTime <*> pure level <*> pure source <*> pure msg <*> pure context
  atomically $ do
    entries <- readTVar (getLoggerVar logger)
    writeTVar (loggerVar logger) (entry : entries)

-- | Get logs within time range
getLogsSince :: Logger -> UTCTime -> IO [LogEntry]
getLogsSince logger sinceTime = do
  entries <- readTVarIO (loggerVar logger)
  return $ filter (\e -> logTimestamp e > sinceTime) entries

-- | Set log level filter
setLogLevel :: Logger -> LogLevel -> IO ()
setLogLevel logger newLevel = do
  -- Implementation for filtering
  return ()

-- | Helper to get var (simplified)
getLoggerVar :: Logger -> TVar [LogEntry]
getLoggerVar (Logger v) = v

loggerVar :: Lens' Logger (TVar [LogEntry])
loggerVar = lens getLoggerVar (\_ v -> Logger v)

-- | JSON serialization helper
instance ToJSON LogEntry where
  toJSON LogEntry {..} =
    object
      [ "timestamp" .= logTimestamp,
        "level" .= logLevel,
        "source" .= logSource,
        "message" .= logMessage,
        "context" .= logContext
      ]
