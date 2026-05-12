-- | WebSocket handler module for real-time notifications
-- Provides: (1) WebSocket connection handler, (2) Event broadcasting,
-- (3) Room-based subscriptions for entity types
module Surypus.WebSocket (
  WebSocketHandler,
  initWebSocketHandler,
  handleWebSocket,
  broadcastToRoom,
  subscribeRoom,
  unsubscribeRoom
) where

import Control.Concurrent.STM
import Control.Monad (forever)
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as M
import Data.Text (Text)
import Network.Websocket (Connection)
import qualified Network.Websocket as WS

-- | WebSocket handler managing connections and rooms
data WebSocketHandler = WebSocketHandler
  { handlerConnections :: TVar (Map Text [Connection])
  -- ^ Connections by room
  , handlerRooms :: TVar (Map Text Text)
  -- ^ ConnectionID -> room mapping
  }

-- | Initialize WebSocket handler
initWebSocketHandler :: IO WebSocketHandler
initWebSocketHandler = do
  conns <- newTVarIO M.empty
  rooms <- newTVarIO M.empty
  return $ WebSocketHandler conns rooms

-- | Handle new WebSocket connection
handleWebSocket :: WebSocketHandler -> Connection -> IO ()
handleWebSocket handler conn = do
  -- Get connection ID (simplified - in production use proper UUID)
  let connId = "conn-" <> show (hash conn)

  -- Join default room
  atomically $ do
    modifyTVar (handlerConnections handler) (M.insertWith (++) "default" [conn])
    modifyTVar (handlerRooms handler) (M.insert connId "default")

  -- Listen for messages
  forever $ do
    msg <- WS.receiveMessage conn
    case msg of
      WS.Text txt -> handleMessage handler connId txt
      WS.Binary _ -> return ()
      WS.CloseEvent -> do
        cleanupConnection handler connId
        WS.sendClose "Connection closed" conn

-- | Handle incoming message
handleMessage :: WebSocketHandler -> Text -> Text -> IO ()
handleMessage handler connId msg = do
  case words msg of
    ("join":room:_) -> do
      atomically $ do
        modifyTVar (handlerConnections handler) (M.insertWith (++) connId [room])
        modifyTVar (handlerRooms handler) (M.insert connId room)
    _ -> return ()

-- | Broadcast to room
broadcastToRoom :: WebSocketHandler -> Text -> Text -> IO ()
broadcastToRoom handler room msg = do
  conns <- readTVarIO (handlerConnections handler)
  let roomConns = M.findWithDefault [] room conns
  mapM_ (\c -> WS.sendMessage (WS.Text msg) c) roomConns

-- | Subscribe connection to room
subscribeRoom :: WebSocketHandler -> Text -> Connection -> IO ()
subscribeRoom handler room conn =
  atomically $ do
    modifyTVar (handlerConnections handler) (M.insertWith (++) room [conn])
    modifyTVar (handlerRooms handler) (M.insert (show conn) room)

-- | Unsubscribe connection from room
unsubscribeRoom :: WebSocketHandler -> Text -> Connection -> IO ()
unsubscribeRoom handler room conn =
  atomically $ do
    modifyTVar (handlerConnections handler) $ \conns ->
      case M.lookup room conns of
        Just conns' -> M.insert room (filter (/= conn) conns') conns
        Nothing -> conns

-- | Cleanup disconnected connection
cleanupConnection :: WebSocketHandler -> Text -> IO ()
cleanupConnection handler connId =
  atomically $ do
    modifyTVar (handlerConnections handler) $ \conns ->
      M.map (\cs -> filter (/= connId) cs) conns
    modifyTVar (handlerRooms handler) (M.delete connId)

-- | Helper for hashing
hash :: a -> Int
hash _ = 0