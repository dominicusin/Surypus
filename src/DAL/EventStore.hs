{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE Unsafe #-}

module DAL.EventStore
   ( Event   (..),
     appendEvent,
     appendEventBroadcast,
     getEvents,
     getEventsFrom,
     replayAccount,
     getLatestSequence,
     setWebSocketBroadcaster,
   )
   where

import Data.Aeson (Value, encode)
import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import Data.Time (UTCTime)
import Data.UUID (UUID)
import GHC.Generics (Generic)
import System.IO.Unsafe (unsafePerformIO)
import Control.Concurrent.MVar (MVar, newMVar, putMVar, readMVar)
import qualified Data.ByteString.Lazy as LBS
import DAL.Database (Pool, usePool)

-- | Domain Event data structure matching the event_store table
data Event = Event
  { eventId :: UUID,
    eventAggregateId :: Int64,
    eventAggregateType :: Text,
    eventEventType :: Text,
    eventEventVersion :: Int,
    eventEventData :: Value,
    eventEventMetadata :: Maybe Value,
    eventSequenceNumber :: Int64,
    eventOccurredAt :: UTCTime,
    eventCreatedAt :: UTCTime
  }
  deriving (Show, Generic)

-- | Event broadcast callback type
type BroadcastCallback = Int64 -> Text -> Text -> Value -> IO ()

-- | Global WebSocket broadcaster (set at application startup)
{-# NOINLINE globalBroadcaster #-}
globalBroadcaster :: MVar (Maybe BroadcastCallback)
globalBroadcaster = unsafePerformIO (newMVar Nothing)

-- | Set the global WebSocket broadcaster
setWebSocketBroadcaster :: BroadcastCallback -> IO ()
setWebSocketBroadcaster callback = putMVar globalBroadcaster (Just callback)

-- | Table definition for event_store (simplified - using Hasql instead of Opaleye)
-- eventStoreTable :: OE.Table ... -- Removed Opaleye dependency

-- | Statement to append a new event (simplified - using Hasql instead of Opaleye)
-- appendEventStmt :: OE.Insert OE.PGString ()
-- appendEventStmt = OE.insert eventStoreTable ... -- Removed Opaleye dependency

-- | Query to get events for an aggregate (simplified - using Hasql instead of Opaleye)
-- getEventsQuery :: OE.Query ... -- Removed Opaleye dependency

-- | Query to get events for an aggregate starting from a sequence number (simplified)
-- getEventsFromQuery :: OE.Query ... -- Removed Opaleye dependency

-- | Query to get the latest sequence number for an aggregate (simplified)
-- getLatestSequenceQuery :: OE.Query ... -- Removed Opaleye dependency

-- | Get the latest sequence number for an aggregate (stub implementation)
getLatestSequence :: Pool -> Int64 -> Text -> IO (Either Text (Maybe Int64))
getLatestSequence pool aggId aggType = pure $ Right Nothing  -- Stub implementation

-- | Append event to store with optional broadcast (stub implementation)
appendEvent :: Pool -> Int64 -> Text -> Text -> Int -> Value -> Maybe Value -> Int64 -> IO (Either Text ())
appendEvent pool aggId aggType evType evVer evData evMeta seqNum = pure $ Right ()  -- Stub implementation

-- | Append event and broadcast to WebSocket room (stub implementation)
appendEventBroadcast :: Pool -> Int64 -> Text -> Text -> Int -> Value -> Maybe Value -> Int64 -> Text -> IO (Either Text ())
appendEventBroadcast pool aggId aggType evType evVer evData evMeta seqNum room = do
  -- Broadcast to WebSocket room via global broadcaster
  broadcaster <- readMVar globalBroadcaster
  case broadcaster of
    Just broadcast -> do
      _ <- broadcast aggId aggType evType evData
      pure $ Right ()
    Nothing -> pure $ Right () -- No broadcaster set, skip broadcast

-- | Get all events for an aggregate (stub implementation)
getEvents :: Pool -> Int64 -> Text -> IO (Either Text [Event])
getEvents pool aggId aggType = pure $ Right []  -- Stub implementation

-- | Get events for an aggregate from a specific sequence number (stub implementation)
getEventsFrom :: Pool -> Int64 -> Text -> Int64 -> IO (Either Text [Event])
getEventsFrom pool aggId aggType seqFrom = pure $ Right []  -- Stub implementation

-- | Replay account from events (stub implementation)
replayAccount :: Pool -> Int64 -> IO (Either Text [Event])
replayAccount pool accountId = pure $ Right []  -- Stub implementation
