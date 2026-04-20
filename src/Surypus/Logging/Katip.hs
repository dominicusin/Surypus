{-# LANGUAGE OverloadedStrings #-}

module Surypus.Logging.Katip
  ( LogEnv (..),
    initLogger,
    logInfo,
    logDebug,
    logError,
  )
where

import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.UUID as UUID
import qualified Data.UUID.V4 as UUID4

-- | Lightweight placeholder logger using correlation IDs
data LogEnv = LogEnv
  { leCorrelationId :: Text
  }

initLogger :: IO LogEnv
initLogger = pure $ LogEnv "<root>"

logInfo :: Text -> Text -> IO ()
logInfo cid msg = putStrLn $ withCid cid "INFO" msg

logDebug :: Text -> Text -> IO ()
logDebug cid msg = putStrLn $ withCid cid "DEBUG" msg

logError :: Text -> Text -> IO ()
logError cid msg = putStrLn $ withCid cid "ERROR" msg

newCorrelationId :: IO Text
newCorrelationId = do
  uuid <- UUID4.nextRandom
  pure $ UUID.toText uuid

withCid :: Text -> Text -> Text -> String
withCid cid level m = T.unpack $ T.concat ["[", cid, "] ", level, ": ", m]
