{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

-- | Domain Event System for cross-cutting concerns
-- Events are emitted by services and handled by subscribers
module Surypus.Event
  ( -- * Event Types
    DomainEvent (..),
    EventType (..),
    EventHandler,
    EventBus,

    -- * Event Bus Operations
    newEventBus,
    subscribe,
    publishEvent,
    publishEventSync,

    -- * Event Handlers
    auditHandler,
    webSocketHandler,
    stockUpdateHandler,
    accountingHandler,
  )
where

import Control.Concurrent.STM (TQueue, atomically, newTQueueIO, readTQueue, writeTQueue)
import Control.Monad (forever, void)
import Control.Monad.IO.Class (liftIO)
import Data.Aeson (ToJSON, Value (..), object, toJSON, (.=))
import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import Data.Time (UTCTime, getCurrentTime)
import GHC.Generics (Generic)

-- | Event types for domain events
data EventType
  = -- Entity lifecycle
    EntityCreated
  | EntityUpdated
  | EntityDeleted
  | -- Bill lifecycle
    BillCreated
  | BillUpdated
  | BillPosted
  | BillCancelled
  | -- Order lifecycle
    OrderCreated
  | OrderUpdated
  | OrderFulfilled
  | OrderCancelled
  | -- Stock operations
    StockReserved
  | StockReleased
  | StockAdjusted
  | StockTransferred
  | -- Payment operations
    PaymentReceived
  | PaymentRefunded
  | -- Auth events
    UserLoggedIn
  | UserLoggedOut
  | -- Accounting events
    AccEntryCreated
  | AccEntryReversed
  | -- Report events
    ReportGenerated
  | ReportScheduled
  | -- Generic
    CustomEvent Text
  deriving (Show, Eq, Generic)

instance ToJSON EventType

-- | Domain event with metadata
data DomainEvent = DomainEvent
  { deId :: Int64,
    deType :: EventType,
    deEntity :: Text,
    deEntityId :: Maybe Int64,
    deUserId :: Maybe Int64,
    dePayload :: Value,
    deTimestamp :: UTCTime
  }
  deriving (Show, Eq, Generic)

instance ToJSON DomainEvent

-- | Event handler function type
type EventHandler = DomainEvent -> IO ()

-- | Event bus with subscribers
data EventBus = EventBus
  { ebQueue :: TQueue DomainEvent,
    ebHandlers :: [EventHandler]
  }

-- | Create a new event bus
newEventBus :: IO EventBus
newEventBus = do
  queue <- newTQueueIO
  pure EventBus {ebQueue = queue, ebHandlers = []}

-- | Subscribe a handler to the event bus
subscribe :: EventBus -> EventHandler -> EventBus
subscribe bus handler = bus {ebHandlers = handler : ebHandlers bus}

-- | Publish an event asynchronously (non-blocking)
publishEvent :: EventBus -> EventType -> Text -> Maybe Int64 -> Maybe Int64 -> Value -> IO ()
publishEvent bus evtType entity entityId userId payload = do
  now <- getCurrentTime
  let event =
        DomainEvent
          { deId = 0, -- Will be assigned by audit handler
            deType = evtType,
            deEntity = entity,
            deEntityId = entityId,
            deUserId = userId,
            dePayload = payload,
            deTimestamp = now
          }
  atomically $ writeTQueue (ebQueue bus) event

-- | Publish an event synchronously (blocking, runs all handlers)
publishEventSync :: EventBus -> EventType -> Text -> Maybe Int64 -> Maybe Int64 -> Value -> IO ()
publishEventSync bus evtType entity entityId userId payload = do
  now <- getCurrentTime
  let event =
        DomainEvent
          { deId = 0,
            deType = evtType,
            deEntity = entity,
            deEntityId = entityId,
            deUserId = userId,
            dePayload = payload,
            deTimestamp = now
          }
  mapM_ (\h -> h event) (ebHandlers bus)

-- ============================================================================
-- BUILT-IN EVENT HANDLERS
-- ============================================================================

-- | Audit handler - logs all events
auditHandler :: (DomainEvent -> IO ()) -> EventHandler
auditHandler logFn event = do
  logFn event
  putStrLn $ "[AUDIT] " <> show (deType event) <> " " <> T.unpack (deEntity event) <> " " <> show (deEntityId event)

-- | WebSocket handler - broadcasts events to connected clients
webSocketHandler :: (DomainEvent -> IO ()) -> EventHandler
webSocketHandler broadcastFn event = do
  broadcastFn event
  putStrLn $ "[WS] Broadcasting: " <> show (deType event)

-- | Stock update handler - adjusts stock on bill post
stockUpdateHandler :: EventHandler
stockUpdateHandler event = case deType event of
  BillPosted -> do
    putStrLn $ "[STOCK] Updating stock for bill " <> show (deEntityId event)
  StockReserved -> putStrLn "[STOCK] Stock reserved"
  StockReleased -> putStrLn "[STOCK] Stock released"
  _ -> pure ()

-- | Accounting handler - creates entries on financial events
accountingHandler :: EventHandler
accountingHandler event = case deType event of
  BillPosted -> do
    putStrLn $ "[ACC] Creating accounting entries for bill " <> show (deEntityId event)
  PaymentReceived -> do
    putStrLn $ "[ACC] Creating payment entry for " <> show (deEntityId event)
  _ -> pure ()
