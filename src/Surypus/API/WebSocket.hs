-- | WebSocket API
--
-- This module provides WebSocket functionality for real-time communication.
module Surypus.API.WebSocket
  ( startWebSocketServer,
  )
where

import qualified Surypus.WebSocket as WS

startWebSocketServer :: Int -> IO ()
startWebSocketServer port = do
  hub <- WS.newWebSocketHub
  WS.runWebSocketServer port hub
