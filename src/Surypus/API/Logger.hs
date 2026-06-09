{-# LANGUAGE OverloadedStrings #-}

-- | Structured JSON logging module
module Surypus.API.Logger (
    LogLevel (..),
    LogField,
    Logger,
    initLogger,
    logMessage,
    logDebug,
    logInfo,
    logWarn,
    logError,
    withCorrelationId,
    getCorrelationId,
    logDBQuery,
) where

import Data.Aeson (object, (.=))
import qualified Data.Aeson as A
import Data.Aeson.Key (fromText)
import Data.IORef
import Data.Text (Text)
import qualified Data.Text as T
import Data.Time.Clock (getCurrentTime)
import Data.Time.Format (formatTime, defaultTimeLocale)
import qualified Data.ByteString.Lazy.Char8 as LBC
import System.IO (stdout, hFlush)
import Control.Monad (when)

data LogLevel = Debug | Info | Warn | Error deriving (Show, Eq, Ord, Enum, Bounded)

type LogField = (String, String)

data Logger = Logger
    { loggerLevel :: LogLevel
    , loggerCorrId :: IORef (Maybe String)
    }

initLogger :: LogLevel -> IO Logger
initLogger level = do
    corrId <- newIORef Nothing
    return $ Logger level corrId

levelToText :: LogLevel -> Text
levelToText Debug = "DEBUG"
levelToText Info  = "INFO"
levelToText Warn  = "WARN"
levelToText Error = "ERROR"

logJson :: Logger -> LogLevel -> String -> [LogField] -> IO ()
logJson logger lvl msg fields = do
    mCorrId <- readIORef (loggerCorrId logger)
    now <- getCurrentTime
    let ts = T.pack $ formatTime defaultTimeLocale "%FT%T%QZ" now
        jsonFields = case mCorrId of
            Just cid -> ("correlation_id", T.pack cid) : map (\(k, v) -> (T.pack k, T.pack v)) fields
            Nothing  -> map (\(k, v) -> (T.pack k, T.pack v)) fields
        fieldPairs = map (\(k, v) -> fromText k .= v) jsonFields
        entry = object $
            [ "timestamp" .= ts
            , "level" .= levelToText lvl
            , "message" .= T.pack msg
            ] ++ fieldPairs
    LBC.hPutStrLn stdout (A.encode entry)
    hFlush stdout

logMessage :: Logger -> LogLevel -> String -> [LogField] -> IO ()
logMessage logger lvl msg fields =
    when (lvl >= loggerLevel logger) $
        logJson logger lvl msg fields

logDebug :: Logger -> String -> [LogField] -> IO ()
logDebug logger msg fields = logMessage logger Debug msg fields

logInfo :: Logger -> String -> [LogField] -> IO ()
logInfo logger msg fields = logMessage logger Info msg fields

logWarn :: Logger -> String -> [LogField] -> IO ()
logWarn logger msg fields = logMessage logger Warn msg fields

logError :: Logger -> String -> [LogField] -> IO ()
logError logger msg fields = logMessage logger Error msg fields

withCorrelationId :: Logger -> String -> IO a -> IO a
withCorrelationId logger cid action = do
    old <- readIORef (loggerCorrId logger)
    writeIORef (loggerCorrId logger) (Just cid)
    result <- action
    writeIORef (loggerCorrId logger) old
    return result

getCorrelationId :: Logger -> IO (Maybe String)
getCorrelationId logger = readIORef (loggerCorrId logger)

logDBQuery :: Logger -> String -> [LogField] -> IO ()
logDBQuery logger query fields =
    logMessage logger Debug ("DB: " ++ query) fields
