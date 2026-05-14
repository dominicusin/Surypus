{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE NamedFieldPuns #-}

-- | Structured logging module (stub implementation)
module Surypus.API.Logger
  ( LogLevel(..)
  , LogField
  , Logger
  , initLogger
  , logMessage
  , logDebug
  , logInfo
  , logWarn
  , logError
  , withCorrelationId
  , getCorrelationId
  , logDBQuery
  ) where

import Control.Concurrent (ThreadId, myThreadId)
import Data.IORef (IORef, atomicModifyIORef', newIORef, readIORef)
import qualified Data.Text as T
import System.Environment (lookupEnv)

-- | Log levels
data LogLevel = LogDebug | LogInfo | LogWarn | LogError | LogCritical
  deriving (Show, Eq, Ord, Enum)

-- | Log field for structured context
type LogField = (T.Text, T.Text)

-- | Logger state with correlation ID support (stub)
data Logger = Logger
  { currentLevel :: IORef LogLevel,
    correlationId :: IORef (Maybe T.Text)
  }

-- | Initialize logger from environment (stub)
initLogger :: IO Logger
initLogger = do
  levelStr <- lookupEnv "LOG_LEVEL"
  let level = case levelStr of
        Just "DEBUG" -> LogDebug
        Just "WARN" -> LogWarn
        Just "ERROR" -> LogError
        Just "CRITICAL" -> LogCritical
        _ -> LogInfo  -- Default to INFO
  levelRef <- newIORef level
  corrIdRef <- newIORef Nothing
  return $ Logger levelRef corrIdRef

-- | Check if a message should be logged based on level
shouldLog :: Logger -> LogLevel -> IO Bool
shouldLog Logger {currentLevel} msgLevel = do
  current <- readIORef currentLevel
  return (msgLevel >= current)

-- | Format a log message with structured fields
formatLogMessage :: LogLevel -> T.Text -> [LogField] -> T.Text -> T.Text
formatLogMessage level source fields msg =
  let levelStr = case level of
        LogDebug -> "DEBUG"
        LogInfo -> "INFO"
        LogWarn -> "WARN"
        LogError -> "ERROR"
        LogCritical -> "CRITICAL"
      fieldsStr =
        if null fields
          then ""
          else " " <> T.intercalate " " (map (\(k, v) -> "\"" <> k <> "\":\"" <> v <> "\"") fields)
   in "[" <> levelStr <> "] [" <> source <> "]" <> fieldsStr <> " " <> msg

-- | Log a message at a specific level (stub - prints to stdout)
logMessage :: Logger -> LogLevel -> T.Text -> T.Text -> [LogField] -> IO ()
logMessage logger level source msg fields = do
  should <- shouldLog logger level
  if should
    then do
      threadId <- myThreadId
      let threadStr = show (hashThreadId threadId)
      let fullMsg = formatLogMessage level source fields msg
      putStrLn $ "[Thread " ++ threadStr ++ "] " ++ T.unpack fullMsg
    else return ()

-- | Hash thread ID for brevity
hashThreadId :: ThreadId -> Int
hashThreadId _ = 0  -- Simplified - in production, hash the thread ID

-- | Debug level logging
logDebug :: Logger -> T.Text -> T.Text -> [LogField] -> IO ()
logDebug = \logger source msg fields -> logMessage logger LogDebug source msg fields

-- | Info level logging
logInfo :: Logger -> T.Text -> T.Text -> [LogField] -> IO ()
logInfo = \logger source msg fields -> logMessage logger LogInfo source msg fields

-- | Warn level logging
logWarn :: Logger -> T.Text -> T.Text -> [LogField] -> IO ()
logWarn = \logger source msg fields -> logMessage logger LogWarn source msg fields

-- | Error level logging
logError :: Logger -> T.Text -> T.Text -> [LogField] -> IO ()
logError = \logger source msg fields -> logMessage logger LogError source msg fields

-- | Set correlation ID for the current request context
withCorrelationId :: Logger -> T.Text -> IO a -> IO a
withCorrelationId Logger {correlationId} cid action = do
  atomicModifyIORef' correlationId (\_ -> (Just cid, ()))
  result <- action
  atomicModifyIORef' correlationId (\_ -> (Nothing, ()))
  return result

-- | Get current correlation ID
getCorrelationId :: Logger -> IO (Maybe T.Text)
getCorrelationId Logger {correlationId} = readIORef correlationId

-- | Log a database query with timing
logDBQuery :: Logger -> T.Text -> Double -> [LogField] -> IO ()
logDBQuery logger query duration fields =
  let timingField = ("duration_ms", T.pack (show (round (duration * 1000) :: Int)))
   in logInfo logger "DB" query (timingField : fields)