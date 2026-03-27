{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Surypus.WebSocket
  ( NotificationType (..),
    WebSocketMessage (..),
    WebSocketHub,
    newWebSocketHub,
    runWebSocketServer,
    broadcastMessage,
  )
where

import Control.Concurrent.STM
import Control.Exception (SomeException, catch)
import Control.Monad (forM, forever, when)
import Data.Aeson (ToJSON, Value, encode, toJSON)
import Data.Maybe (catMaybes)
import Data.Text (Text)
import Data.Time.Clock (UTCTime)
import GHC.Generics (Generic)
import Network.HTTP.Types (status400)
import Network.Wai (Application, responseLBS)
import Network.Wai.Handler.Warp (run)
import Network.Wai.Handler.WebSockets (websocketsOr)
import qualified Network.WebSockets as WS

data NotificationType
  = NTPersonChanged
  | NTGoodsChanged
  | NTBillChanged
  | NTOrderChanged
  | NTPaymentChanged
  | NTTaxChanged
  | NTCurrencyChanged
  | NTSystem
  deriving (Show, Eq, Generic)

instance ToJSON NotificationType where
  toJSON nt = case nt of
    NTPersonChanged -> toJSON ("person_changed" :: Text)
    NTGoodsChanged -> toJSON ("goods_changed" :: Text)
    NTBillChanged -> toJSON ("bill_changed" :: Text)
    NTOrderChanged -> toJSON ("order_changed" :: Text)
    NTPaymentChanged -> toJSON ("payment_changed" :: Text)
    NTTaxChanged -> toJSON ("tax_changed" :: Text)
    NTCurrencyChanged -> toJSON ("currency_changed" :: Text)
    NTSystem -> toJSON ("system" :: Text)

data WebSocketMessage = WebSocketMessage
  { wsmType :: NotificationType,
    wsmEvent :: Text,
    wsmPayload :: Value,
    wsmTimestamp :: UTCTime
  }
  deriving (Show, Eq, Generic)

instance ToJSON WebSocketMessage

data WebSocketHub = WebSocketHub
  { wshNextId :: TVar Int,
    wshClients :: TVar [(Int, WS.Connection)]
  }

newWebSocketHub :: IO WebSocketHub
newWebSocketHub = do
  nextIdVar <- newTVarIO 1
  clientsVar <- newTVarIO []
  pure $ WebSocketHub nextIdVar clientsVar

runWebSocketServer :: Int -> WebSocketHub -> IO ()
runWebSocketServer port hub = do
  putStrLn $ "WebSocket server listening on port " <> show port
  run port app
  where
    app :: Application
    app =
      websocketsOr
        WS.defaultConnectionOptions
        (webSocketApp hub)
        (\_ respond -> respond (responseLBS status400 [("Content-Type", "text/plain")] "WebSocket endpoint"))

webSocketApp :: WebSocketHub -> WS.ServerApp
webSocketApp hub pendingConnection = do
  connection <- WS.acceptRequest pendingConnection
  clientId <- registerClient hub connection
  putStrLn $ "WebSocket client connected: " <> show clientId
  ( forever $ do
      _ <- WS.receiveDataMessage connection
      pure ()
    )
    `catch` \(_ :: SomeException) -> pure ()
  unregisterClient hub clientId
  putStrLn $ "WebSocket client disconnected: " <> show clientId

registerClient :: WebSocketHub -> WS.Connection -> IO Int
registerClient hub connection = atomically $ do
  currentId <- readTVar (wshNextId hub)
  modifyTVar' (wshNextId hub) (+ 1)
  modifyTVar' (wshClients hub) ((currentId, connection) :)
  pure currentId

unregisterClient :: WebSocketHub -> Int -> IO ()
unregisterClient hub clientId =
  atomically $ modifyTVar' (wshClients hub) (filter (\(cid, _) -> cid /= clientId))

broadcastMessage :: WebSocketHub -> WebSocketMessage -> IO ()
broadcastMessage hub message = do
  clients <- readTVarIO (wshClients hub)
  failedClientIds <-
    fmap catMaybes . forM clients $ \(clientId, connection) -> do
      (WS.sendTextData connection (encode message) >> pure Nothing)
        `catch` \(_ :: SomeException) -> pure (Just clientId)
  when (not (null failedClientIds)) $
    atomically $
      modifyTVar' (wshClients hub) (filter (\(cid, _) -> cid `notElem` failedClientIds))
