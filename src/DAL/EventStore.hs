{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE ScopedTypeVariables #-}

module DAL.EventStore
   ( Event (..),
     appendEvent,
     appendEventBroadcast,
     getEvents,
     getEventsFrom,
     replayAccount,
     getLatestSequence,
     setWebSocketBroadcaster,
   )
   where

import Control.Concurrent.MVar (MVar, newMVar, putMVar, readMVar)
import DAL.Database (ConnectionPool, runDb)
import DAL.Schema
  ( EventStoreEntity (..),
    EntityField
      ( EventStoreEntityAggregateId
      , EventStoreEntityAggregateType
      , EventStoreEntityEventType
      , EventStoreEntityEventVersion
      , EventStoreEntityEventData
      , EventStoreEntityEventMetadata
      , EventStoreEntitySequenceNumber
      , EventStoreEntityOccurredAt
      , EventStoreEntityCreatedAt
      ),
  )
import Data.Aeson (Value, encode, decode)
import qualified Data.ByteString.Lazy as LBS
import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text.Encoding as TE
import Data.Time (UTCTime, getCurrentTime)
import Database.Persist.Sql (insert, selectList, selectFirst, (==.), (>=.), entityVal)
import Database.Persist.Types (SelectOpt (Desc, Asc))
import GHC.Generics (Generic)
import System.IO.Unsafe (unsafePerformIO)

data Event = Event
  { eventAggregateId    :: Int64
  , eventAggregateType  :: Text
  , eventEventType      :: Text
  , eventEventVersion   :: Int
  , eventEventData      :: Value
  , eventEventMetadata  :: Maybe Value
  , eventSequenceNumber :: Int64
  , eventOccurredAt     :: UTCTime
  , eventCreatedAt      :: UTCTime
  }
  deriving (Show, Generic)

type BroadcastCallback = Int64 -> Text -> Text -> Value -> IO ()

{-# NOINLINE globalBroadcaster #-}
globalBroadcaster :: MVar (Maybe BroadcastCallback)
globalBroadcaster = unsafePerformIO (newMVar Nothing)

setWebSocketBroadcaster :: BroadcastCallback -> IO ()
setWebSocketBroadcaster callback = putMVar globalBroadcaster (Just callback)

decodeJSON :: Text -> Value
decodeJSON txt = case decode (LBS.fromStrict $ TE.encodeUtf8 txt) of
  Just v  -> v
  Nothing -> error "Invalid JSON in database"

encodeJSON :: Value -> Text
encodeJSON v = TE.decodeUtf8 $ LBS.toStrict $ encode v

decodeMaybeJSON :: Maybe Text -> Maybe Value
decodeMaybeJSON Nothing   = Nothing
decodeMaybeJSON (Just t) = case decode (LBS.fromStrict $ TE.encodeUtf8 t) of
  Just v  -> Just v
  Nothing -> Nothing

entityToEvent :: EventStoreEntity -> Event
entityToEvent entity =
  Event
    { eventAggregateId    = eventStoreEntityAggregateId entity
    , eventAggregateType  = eventStoreEntityAggregateType entity
    , eventEventType      = eventStoreEntityEventType entity
    , eventEventVersion   = eventStoreEntityEventVersion entity
    , eventEventData      = decodeJSON (eventStoreEntityEventData entity)
    , eventEventMetadata  = decodeMaybeJSON (eventStoreEntityEventMetadata entity)
    , eventSequenceNumber = eventStoreEntitySequenceNumber entity
    , eventOccurredAt     = eventStoreEntityOccurredAt entity
    , eventCreatedAt      = eventStoreEntityCreatedAt entity
    }

getLatestSequence :: ConnectionPool -> Int64 -> Text -> IO (Either Text (Maybe Int64))
getLatestSequence pool aggId aggType = do
  result <- runDb pool $ selectFirst
    [ EventStoreEntityAggregateId ==. aggId
    , EventStoreEntityAggregateType ==. aggType
    ] [Desc EventStoreEntitySequenceNumber]
  pure $ Right $ fmap (eventStoreEntitySequenceNumber . entityVal) result

appendEvent :: ConnectionPool -> Int64 -> Text -> Text -> Int -> Value -> Maybe Value -> Int64 -> IO (Either Text ())
appendEvent pool aggId aggType evType evVer evData evMeta seqNum = do
  now <- getCurrentTime
  let entity = EventStoreEntity
        { eventStoreEntityAggregateId    = aggId
        , eventStoreEntityAggregateType  = aggType
        , eventStoreEntityEventType      = evType
        , eventStoreEntityEventVersion   = evVer
        , eventStoreEntityEventData      = encodeJSON evData
        , eventStoreEntityEventMetadata  = fmap encodeJSON evMeta
        , eventStoreEntitySequenceNumber = seqNum
        , eventStoreEntityOccurredAt     = now
        , eventStoreEntityCreatedAt      = now
        }
  runDb pool $ insert entity
  pure $ Right ()

appendEventBroadcast :: ConnectionPool -> Int64 -> Text -> Text -> Int -> Value -> Maybe Value -> Int64 -> Text -> IO (Either Text ())
appendEventBroadcast pool aggId aggType evType evVer evData evMeta seqNum _room = do
  result <- appendEvent pool aggId aggType evType evVer evData evMeta seqNum
  broadcaster <- readMVar globalBroadcaster
  case broadcaster of
    Just broadcast -> broadcast aggId aggType evType evData >> pure result
    Nothing        -> pure result

getEvents :: ConnectionPool -> Int64 -> Text -> IO (Either Text [Event])
getEvents pool aggId aggType = do
  result <- runDb pool $ selectList
    [ EventStoreEntityAggregateId ==. aggId
    , EventStoreEntityAggregateType ==. aggType
    ] [Asc EventStoreEntitySequenceNumber]
  pure $ Right $ map (entityToEvent . entityVal) result

getEventsFrom :: ConnectionPool -> Int64 -> Text -> Int64 -> IO (Either Text [Event])
getEventsFrom pool aggId aggType seqFrom = do
  result <- runDb pool $ selectList
    [ EventStoreEntityAggregateId ==. aggId
    , EventStoreEntityAggregateType ==. aggType
    , EventStoreEntitySequenceNumber >=. seqFrom
    ] [Asc EventStoreEntitySequenceNumber]
  pure $ Right $ map (entityToEvent . entityVal) result

replayAccount :: ConnectionPool -> Int64 -> IO (Either Text [Event])
replayAccount pool accountId = do
  result <- runDb pool $ selectList
    [ EventStoreEntityAggregateId ==. accountId
    ] [Asc EventStoreEntitySequenceNumber]
  pure $ Right $ map (entityToEvent . entityVal) result
