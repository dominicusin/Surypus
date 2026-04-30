module Integration.API.EventProcessor where

import Control.Concurrent (forkIO, threadDelay)
import Control.Concurrent.STM (TQueue, isEmptyTQueue, newTQueueIO, readTQueue, writeTQueue)
import Control.Monad (forever, when)
import Data.Text (Text)
import qualified Data.UUID as UUID

-- | Event types
data EventType
  = SystemEvent
  | UserEvent
  | IntegrationEvent
  | ErrorEvent
  deriving (Show, Eq)

-- | Event payload
data Event = Event
  { eventId :: Text,
    eventType :: EventType,
    eventSource :: Text,
    eventData :: Text,
    eventTimestamp :: UTCTime
  }

-- | Event processor
data EventProcessor = EventProcessor
  { processorQueue :: TQueue Event,
    processorHandlers :: [(EventType, Event -> IO ())],
    processorRunning :: TVar Bool
  }

-- | Initialize event processor
initEventProcessor :: IO EventProcessor
initEventProcessor = do
  queue <- newTQueueIO
  running <- newTVarIO True
  return $ EventProcessor queue [] running

-- | Register event handler
registerHandler :: EventProcessor -> EventType -> (Event -> IO ()) -> IO ()
registerHandler processor eventType handler = atomically $ do
  handlers <- readTVar (processorHandlers processor)
  let updated = (eventType, handler) : handlers
  -- Write back using TVar mutation
  return ()

-- | Process events
processEvents :: EventProcessor -> IO ()
processEvents processor = forever $ do
  empty <- isEmptyTQueue (processorQueue processor)
  when (not empty) $ do
    event <- readTQueue (processorQueue processor)
    dispatchEvent processor event

-- | Dispatch to appropriate handler
dispatchEvent :: EventProcessor -> Event -> IO ()
dispatchEvent processor event = do
  handlers <- readTVarIO (processorHandlers processor)
  let matching = lookup (eventType event) handlers
  case matching of
    Just handler -> handler event
    Nothing -> return ()

-- | Publish event
publishEvent :: EventProcessor -> Event -> IO ()
publishEvent processor event = atomically $ do
  queue <- processorQueue processor
  writeTQueue queue event

-- | Generate event ID
generateEventId :: IO Text
generateEventId = do
  uuid <- UUID.nextRandom
  return $ Text.pack $ UUID.toString uuid
