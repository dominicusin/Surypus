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
    jwtWebSocketApp,
    runWebSocketServerWithAuth,
    jwtWebSocketAppWithPath,
    acceptConnectionWithPath,
    handleMessage,
    broadcastToRole,
    broadcastEvent,
  )
where

import Control.Concurrent.STM
import Control.Exception (SomeException, catch)
import Control.Monad (forM, forM_, forever, unless, void)
import Data.Aeson (ToJSON, Value, encode, toJSON)
import Data.Maybe (catMaybes)
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.Encoding as TE
import Data.Time.Clock (UTCTime, getCurrentTime)
import GHC.Generics (Generic)
import qualified Network.WebSockets as WS
import Surypus.JWT (JWTConfig, JWTPayload, getJwtRole, validateAccessToken)

data NotificationType
  = NTPersonChanged
  | NTGoodsChanged
  | NTBillChanged
  | NTOrderChanged
  | NTPaymentChanged
  | NTTaxChanged
  | NTCurrencyChanged
  | NTAccountingChanged
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
    NTAccountingChanged -> toJSON ("accounting_changed" :: Text)
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
    wshClients :: TVar [(Int, WS.Connection, Maybe JWTPayload)]
  }

newWebSocketHub :: IO WebSocketHub
newWebSocketHub = do
  nextIdVar <- newTVarIO 1
  clientsVar <- newTVarIO []
  pure $ WebSocketHub nextIdVar clientsVar

runWebSocketServer :: Int -> WebSocketHub -> IO ()
runWebSocketServer port hub = runWebSocketServerWithAuth port hub Nothing

runWebSocketServerWithAuth :: Int -> WebSocketHub -> Maybe JWTConfig -> IO ()
runWebSocketServerWithAuth port _ _ = do
  putStrLn $ "WebSocket server placeholder on port " <> show port
  putStrLn "WebSocket functionality needs migration to Servant"

jwtWebSocketApp :: WebSocketHub -> Maybe JWTConfig -> WS.ServerApp
jwtWebSocketApp hub mConfig pendingConnection = do
  let request = WS.pendingRequest pendingConnection
  case mConfig of
    Nothing -> acceptConnection hub Nothing pendingConnection
    Just config -> case getTokenFromRequest request of
      Nothing -> void $ WS.rejectRequest pendingConnection "Missing token"
      Just token -> do
        result <- validateAccessToken config token
        case result of
          Left _ -> void $ WS.rejectRequest pendingConnection "Invalid token"
          Right payload -> acceptConnection hub (Just payload) pendingConnection

jwtWebSocketAppWithPath :: WebSocketHub -> Maybe JWTConfig -> Text -> WS.ServerApp
jwtWebSocketAppWithPath hub mConfig path pendingConnection = do
  let request = WS.pendingRequest pendingConnection
  case mConfig of
    Nothing -> acceptConnectionWithPath hub Nothing path pendingConnection
    Just config -> case getTokenFromRequest request of
      Nothing -> void $ WS.rejectRequest pendingConnection "Missing token"
      Just token -> do
        result <- validateAccessToken config token
        case result of
          Left _ -> void $ WS.rejectRequest pendingConnection "Invalid token"
          Right payload -> acceptConnectionWithPath hub (Just payload) path pendingConnection

getTokenFromRequest :: WS.RequestHead -> Maybe Text
getTokenFromRequest request = do
  let query = TE.decodeUtf8 (WS.requestPath request)
  case T.splitOn "?" query of
    [_path, params] -> do
      let pairs = T.splitOn "&" params
      tokenPair <- find (T.isPrefixOf "token=") pairs
      let token = T.drop 5 tokenPair
      if T.null token then Nothing else Just token
    _ -> Nothing
  where
    find _ [] = Nothing
    find f (x : xs) = if f x then Just x else find f xs

acceptConnection :: WebSocketHub -> Maybe JWTPayload -> WS.ServerApp
acceptConnection hub mPayload pendingConnection = do
  connection <- WS.acceptRequest pendingConnection
  clientId <- registerClient hub connection mPayload
  putStrLn $ "WebSocket client connected: " <> show clientId
  forever
    ( do
        _ <- WS.receiveDataMessage connection
        pure ()
    )
    `catch` \(_ :: SomeException) -> pure ()
  unregisterClient hub clientId
  putStrLn $ "WebSocket client disconnected: " <> show clientId

acceptConnectionWithPath :: WebSocketHub -> Maybe JWTPayload -> Text -> WS.ServerApp
acceptConnectionWithPath hub mPayload path pendingConnection = do
  connection <- WS.acceptRequest pendingConnection
  clientId <- registerClient hub connection mPayload
  putStrLn $ "WebSocket client connected: " <> show clientId <> " path: " <> T.unpack path
  forever
    ( do
        msg <- WS.receiveDataMessage connection
        handleMessage hub clientId path msg
    )
    `catch` \(_ :: SomeException) -> pure ()
  unregisterClient hub clientId
  putStrLn $ "WebSocket client disconnected: " <> show clientId

handleMessage :: WebSocketHub -> Int -> Text -> WS.DataMessage -> IO ()
handleMessage hub _ path _ = do
  clients <- readTVarIO (wshClients hub)
  let filteredClients = filter (\(_, _, mPayload) -> canReceive path mPayload) clients
  forM_ filteredClients $ \(_, connection, _) ->
    WS.sendTextData connection ("{\"event\":\"update\"}" :: Text) `catch` \(_ :: SomeException) -> pure ()
  where
    canReceive _ Nothing = True
    canReceive "admin" (Just _) = True
    canReceive _ (Just payload) = getJwtRole payload `elem` ["admin", "manager"]

registerClient :: WebSocketHub -> WS.Connection -> Maybe JWTPayload -> IO Int
registerClient hub connection mPayload = atomically $ do
  currentId <- readTVar (wshNextId hub)
  modifyTVar' (wshNextId hub) (+ 1)
  modifyTVar' (wshClients hub) ((currentId, connection, mPayload) :)
  pure currentId

unregisterClient :: WebSocketHub -> Int -> IO ()
unregisterClient hub clientId =
  atomically $ modifyTVar' (wshClients hub) (filter (\(cid, _, _) -> cid /= clientId))

broadcastMessage :: WebSocketHub -> WebSocketMessage -> IO ()
broadcastMessage hub message = do
  clients <- readTVarIO (wshClients hub)
  failedClientIds <-
    fmap catMaybes . forM clients $ \(clientId, connection, _mPayload) -> do
      (WS.sendTextData connection (encode message) >> pure Nothing)
        `catch` \(_ :: SomeException) -> pure (Just clientId)
  unless (null failedClientIds) . atomically $ modifyTVar' (wshClients hub) (filter (\(cid, _, _) -> cid `notElem` failedClientIds))

broadcastToRole :: WebSocketHub -> Text -> WebSocketMessage -> IO ()
broadcastToRole hub role message = do
  clients <- readTVarIO (wshClients hub)
  let targetClients =
        filter
          ( \(_, _, mPayload) -> case mPayload of
              Nothing -> False
              Just p -> getJwtRole p == role || getJwtRole p == "admin"
          )
          clients
  failedClientIds <-
    fmap catMaybes . forM targetClients $ \(clientId, connection, _) -> do
      (WS.sendTextData connection (encode message) >> pure Nothing)
        `catch` \(_ :: SomeException) -> pure (Just clientId)
  unless (null failedClientIds) . atomically $ modifyTVar' (wshClients hub) (filter (\(cid, _, _) -> cid `notElem` failedClientIds))

-- | Broadcast a generic event to all connected clients via the event bus
broadcastEvent :: WebSocketHub -> NotificationType -> Value -> IO ()
broadcastEvent hub nt payload = do
  t <- getCurrentTime
  let msg = WebSocketMessage nt "event" payload t
  broadcastMessage hub msg
