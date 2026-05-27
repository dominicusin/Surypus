{-# LANGUAGE NamedFieldPuns #-}
{-# LANGUAGE OverloadedStrings #-}

-- | Structured logging module (stub implementation)
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

import Data.IORef
import System.IO.Unsafe (unsafePerformIO)

data LogLevel = Debug | Info | Warn | Error deriving (Show, Eq, Ord, Enum, Bounded)

type LogField = (String, String)

data Logger = Logger
    { loggerLevel :: LogLevel
    , loggerFields :: IORef [LogField]
    , loggerCorrId :: IORef (Maybe String)
    }

{-# NOINLINE theLogger #-}
theLogger :: Logger
theLogger = Logger Info (unsafePerformIO (newIORef [])) (unsafePerformIO (newIORef Nothing))

initLogger :: LogLevel -> IO Logger
initLogger level = do
    fields <- newIORef []
    corrId <- newIORef Nothing
    return $ Logger level fields corrId

logMessage :: Logger -> LogLevel -> String -> [LogField] -> IO ()
logMessage _ _ _ _ = return ()

logDebug, logInfo, logWarn, logError :: Logger -> String -> [LogField] -> IO ()
logDebug _ _ _ = return ()
logInfo _ _ _ = return ()
logWarn _ _ _ = return ()
logError _ _ _ = return ()

withCorrelationId :: Logger -> String -> IO a -> IO a
withCorrelationId _ _ action = action

getCorrelationId :: Logger -> IO (Maybe String)
getCorrelationId _ = return Nothing

logDBQuery :: Logger -> String -> [LogField] -> IO ()
logDBQuery _ _ _ = return ()
