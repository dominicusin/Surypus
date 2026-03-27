{-# LANGUAGE OverloadedStrings #-}

module Surypus.WebSocket
  ( WebSocketMessage (..),
    WSHandler,
    runWebSocketServer,
    broadcastMessage,
    NotificationType (..),
  )
where

import Control.Concurrent (Chan, newChan, writeChan)
import Control.Monad (forever)
import Data.Text (Text)
import qualified Data.Text as T
import Data.Text.Lazy (toStrict)
import Data.Text.Lazy.Encoding (decodeUtf8)
import Network.Wai (Application, Response)
import Network.Wai.Handler.Warp (run)
import qualified Network.Wai.Handler.Warp as Warp
import qualified Network.Wai.Handler.WebSockets as WaiWS
import qualified Network.WebSockets as WS

data NotificationType
  = NTBillUpdate
  | NTOrderUpdate
  | NTStockUpdate
  | NTPaymentUpdate
  | NTSystemMessage
  deriving (Show, Eq)

data WebSocketMessage = WebSocketMessage
  { wsmType :: NotificationType,
    wsmPayload :: Text
  }

type WSHandler = WS.Connection -> IO ()

type WSBroadcast = WebSocketMessage -> IO ()

newWebSocketServer :: IO (WSHandler, WSBroadcast)
newWebSocketServer = do
  chan <- newChan
  let sender conn = forever $ do
        msg <- WS.receiveData conn
        putStrLn $ "Received: " <> T.unpack (toStrict msg)
      broadcaster msg = writeChan chan msg
  return (sender, broadcaster)

runWebSocketServer :: Int -> IO ()
runWebSocketServer port = do
  putStrLn $ "WebSocket server starting on port " <> show port
  run port app
  where
    app :: Application
    app req respond = do
      if WaiWS.isWebSocketsReq req
        then WaiWS.websocketsOr WS.defaultConnectionOptions wsApp (respond emptyResponse)
        else respond emptyResponse
    wsApp :: WS.ServerApp
    wsApp pendingConn = do
      conn <- WS.acceptRequest pendingConn
      putStrLn "Client connected"
      WS.withPingThread conn 30 (return ()) $ forever $ do
        msg <- WS.receiveData conn
        putStrLn $ "Received: " <> T.unpack (toStrict (decodeUtf8 msg))
      putStrLn "Client disconnected"
    emptyResponse :: Response
    emptyResponse = respond (WS.rejectRequest "Not a WebSocket request")

broadcastMessage :: WSBroadcast -> WebSocketMessage -> IO ()
broadcastMessage _broadcaster _msg = do
  putStrLn "Broadcasting message"

messageToText :: WebSocketMessage -> Text
messageToText msg = case wsmType msg of
  NTBillUpdate -> "bill_update:" <> wsmPayload msg
  NTOrderUpdate -> "order_update:" <> wsmPayload msg
  NTStockUpdate -> "stock_update:" <> wsmPayload msg
  NTPaymentUpdate -> "payment_update:" <> wsmPayload msg
  NTSystemMessage -> "system:" <> wsmPayload msg
