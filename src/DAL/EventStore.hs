{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE ScopedTypeVariables #-}

module DAL.EventStore
  ( Event (..),
    appendEvent,
    getEvents,
    getEventsFrom,
    replayAccount,
    getLatestSequence,
  )
where

import Data.Aeson (Value)
import Data.Functor.Contravariant ((>$<))
import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.Encoding as TE
import Data.Time (UTCTime)
import Data.UUID (UUID)
import GHC.Generics (Generic)
import qualified Hasql.Decoders as D
import qualified Hasql.Encoders as E
import Hasql.Pool (Pool, use)
import qualified Hasql.Session as Session
import Hasql.Statement (Statement (..))

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

-- | Decoder for Event row
eventRowDecoder :: D.Row Event
eventRowDecoder =
  Event
    <$> D.column (D.nonNullable D.uuid)
    <*> D.column (D.nonNullable D.int8)
    <*> D.column (D.nonNullable D.text)
    <*> D.column (D.nonNullable D.text)
    <*> (fromIntegral <$> D.column (D.nonNullable D.int4))
    <*> D.column (D.nonNullable D.jsonb)
    <*> D.column (D.nullable D.jsonb)
    <*> D.column (D.nonNullable D.int8)
    <*> D.column (D.nonNullable D.timestamptz)
    <*> D.column (D.nonNullable D.timestamptz)

-- | Statement to append a new event
appendEventStmt :: Statement (Int64, Text, Text, Int, Value, Maybe Value, Int64) ()
appendEventStmt = Statement sql encoder decoder True
  where
    sql =
      "INSERT INTO event_store (aggregate_id, aggregate_type, event_type, event_version, event_data, event_metadata, sequence_number) \
      \VALUES ($1, $2, $3, $4, $5, $6, $7)"
    encoder =
      ((\(a, _, _, _, _, _, _) -> a) >$< E.param (E.nonNullable E.int8))
        <> ((\(_, b, _, _, _, _, _) -> b) >$< E.param (E.nonNullable E.text))
        <> ((\(_, _, c, _, _, _, _) -> c) >$< E.param (E.nonNullable E.text))
        <> ((\(_, _, _, d, _, _, _) -> d) >$< E.param (E.nonNullable E.int4 . fromIntegral))
        <> ((\(_, _, _, _, e, _, _) -> e) >$< E.param (E.nonNullable E.jsonb))
        <> ((\(_, _, _, _, _, f, _) -> f) >$< E.param (E.nullable E.jsonb))
        <> ((\(_, _, _, _, _, _, g) -> g) >$< E.param (E.nonNullable E.int8))
    decoder = D.noResult

-- | Statement to get events for an aggregate
getEventsStmt :: Statement (Int64, Text) [Event]
getEventsStmt = Statement sql encoder decoder True
  where
    sql =
      "SELECT id, aggregate_id, aggregate_type, event_type, event_version, event_data, event_metadata, sequence_number, occurred_at, created_at \
      \FROM event_store WHERE aggregate_id = $1 AND aggregate_type = $2 ORDER BY sequence_number"
    encoder = (fst >$< E.param (E.nonNullable E.int8)) <> (snd >$< E.param (E.nonNullable E.text))
    decoder = D.rowList eventRowDecoder

-- | Statement to get events for an aggregate starting from a sequence number
getEventsFromStmt :: Statement (Int64, Text, Int64) [Event]
getEventsFromStmt = Statement sql encoder decoder True
  where
    sql =
      "SELECT id, aggregate_id, aggregate_type, event_type, event_version, event_data, event_metadata, sequence_number, occurred_at, created_at \
      \FROM event_store WHERE aggregate_id = $1 AND aggregate_type = $2 AND sequence_number >= $3 ORDER BY sequence_number"
    encoder =
      ((\(a, _, _) -> a) >$< E.param (E.nonNullable E.int8))
        <> ((\(_, b, _) -> b) >$< E.param (E.nonNullable E.text))
        <> ((\(_, _, c) -> c) >$< E.param (E.nonNullable E.int8))
    decoder = D.rowList eventRowDecoder

-- | Statement to get the latest sequence number for an aggregate
getLatestSequenceStmt :: Statement (Int64, Text) (Maybe Int64)
getLatestSequenceStmt = Statement sql encoder decoder True
  where
    sql = "SELECT MAX(sequence_number) FROM event_store WHERE aggregate_id = $1 AND aggregate_type = $2"
    encoder = (fst >$< E.param (E.nonNullable E.int8)) <> (snd >$< E.param (E.nonNullable E.text))
    decoder = D.rowMaybe (D.column (D.nonNullable D.int8))

-- | Append event to store
appendEvent :: Pool -> Int64 -> Text -> Text -> Int -> Value -> Maybe Value -> Int64 -> IO (Either Text ())
appendEvent pool aggId aggType evType evVer evData evMeta seqNum = do
  res <- use pool $ Session.statement (aggId, aggType, evType, evVer, evData, evMeta, seqNum) appendEventStmt
  case res of
    Right () -> pure $ Right ()
    Left err -> pure $ Left $ T.pack $ show err

-- | Get all events for an aggregate
getEvents :: Pool -> Int64 -> Text -> IO (Either Text [Event])
getEvents pool aggId aggType = do
  res <- use pool $ Session.statement (aggId, aggType) getEventsStmt
  case res of
    Right events -> pure $ Right events
    Left err -> pure $ Left $ T.pack $ show err

-- | Get events for an aggregate from a specific sequence number
getEventsFrom :: Pool -> Int64 -> Text -> Int64 -> IO (Either Text [Event])
getEventsFrom pool aggId aggType seqFrom = do
  res <- use pool $ Session.statement (aggId, aggType, seqFrom) getEventsFromStmt
  case res of
    Right events -> pure $ Right events
    Left err -> pure $ Left $ T.pack $ show err

-- | Replay events for an account (specific aggregate type 'account')
replayAccount :: Pool -> Int64 -> IO (Either Text [Event])
replayAccount pool accId = getEvents pool accId "account"

-- | Get the latest sequence number for an aggregate
getLatestSequence :: Pool -> Int64 -> Text -> IO (Either Text Int64)
getLatestSequence pool aggId aggType = do
  res <- use pool $ Session.statement (aggId, aggType) getLatestSequenceStmt
  case res of
    Right (Just s) -> pure $ Right s
    Right Nothing -> pure $ Right 0
    Left err -> pure $ Left $ T.pack $ show err
