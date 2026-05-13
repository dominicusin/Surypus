{-# LANGUAGE OverloadedStrings #-}

module Surypus.WebSocket.RedisPublisher (publishEvent) where

import qualified Database.Redis as R
import Data.ByteString.Char8 (pack)

-- | Publish an event to the Redis channel for WebSocket broadcasting
publishEvent :: Text -> IO ()
publishEvent msg = do
  let connInfo = R.defaultConnectInfo { R.connectHost = "localhost", R.connectPort = 6379 }
  conn <- R.checkedConnect connInfo
  void $ R.runRedis conn $ R.publish [R.pack "surypus:events"] (pack msg)