-- ============================================================================
-- SURYPUS EVENT STORE - Accounting Events
-- US-3-1: Accounts Event Store Implementation
-- ============================================================================

{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE RecordWildCards #-}

module DAL.EventStore
  ( -- * Event Types
    AccountingEvent(..)
  , EventType(..)
  , EventData(..)
  , EventMetadata(..)

    -- * Event Store Operations
  , appendEvent
  , getEvents
  , getEventsFrom
  , replayAccount
  , getLatestSequence
  , initEventStore

    -- * Event Creation Helpers
  , createAccountCreatedEvent
  , createJournalEntryEvent
  , createBalanceAdjustedEvent
  ) where

import Data.Aeson (ToJSON, FromJSON, Value)
import Data.Maybe (fromMaybe)
import Data.Time (UTCTime, getCurrentTime)
import Data.UUID (UUID, nil)
import Data.Int (Int64)
import GHC.Generics (Generic)
import Data.Text (Text)
import Data.IORef (IORef, newIORef, readIORef, atomicModifyIORef')
import GHC.IO (unsafePerformIO)

-- ============================================================================
-- EVENT TYPES
-- ============================================================================

-- | Accounting event types
data EventType
  = AccountCreated
  | AccountUpdated
  | BalanceAdjusted
  | JournalEntryPosted
  | AccountReclassified
  | AccountClosed
  | AccountReopened
  deriving (Show, Eq, Generic, ToJSON, FromJSON)

-- | Event metadata
data EventMetadata = EventMetadata
  { emTrigger :: Maybe Text
  , emUser :: Maybe Text
  , emRequestId :: Maybe UUID
  , emCorrelationId :: Maybe UUID
  } deriving (Show, Eq, Generic, ToJSON, FromJSON)

-- | Event data payload
data EventData = EventData
  { edOldBalance :: Maybe Double
  , edNewBalance :: Maybe Double
  , edChangeAmount :: Maybe Double
  , edAccountCode :: Maybe Text
  , edAccountName :: Maybe Text
  , edAccountType :: Maybe Int
  , edCurrencyId :: Maybe Int64
  , edJournalEntryId :: Maybe Int64
  , edDebitAccountId :: Maybe Int64
  , edCreditAccountId :: Maybe Int64
  , edDescription :: Maybe Text
  , edCustomData :: Maybe Value
  } deriving (Show, Eq, Generic, ToJSON, FromJSON)

-- | Accounting event
data AccountingEvent = AccountingEvent
  { aeId :: UUID
  , aeAggregateId :: Int64
  , aeAggregateType :: Text
  , aeEventType :: EventType
  , aeEventVersion :: Int
  , aeEventData :: EventData
  , aeMetadata :: Maybe EventMetadata
  , aeSequenceNumber :: Int64
  , aeOccurredAt :: UTCTime
  , aeCreatedAt :: UTCTime
  } deriving (Show, Eq, Generic, ToJSON, FromJSON)

-- ============================================================================
-- GLOBAL EVENT STORE STATE
-- ============================================================================

-- | Global event store reference (top-level mutable state for in-memory store)
{-# NOINLINE eventStoreRef #-}
eventStoreRef :: IORef [AccountingEvent]
eventStoreRef = unsafePerformIO (newIORef [])

-- | Initialize the event store (reset to empty)
initEventStore :: IO ()
initEventStore =
  atomicModifyIORef' eventStoreRef (\_ -> ([], ()))

-- ============================================================================
-- EVENT STORE OPERATIONS
-- ============================================================================

-- | Append an event to the store
appendEvent :: Int64 -> EventType -> EventData -> Maybe EventMetadata -> IO (Either Text AccountingEvent)
appendEvent accountId eventType eventData metadata = do
  currentTime <- getCurrentTime
  events <- readIORef eventStoreRef
  let seqNum = 1 + foldr (\e n -> max (aeSequenceNumber e) n) 0 events
  let event = AccountingEvent
        { aeId = nil
        , aeAggregateId = accountId
        , aeAggregateType = "account"
        , aeEventType = eventType
        , aeEventVersion = 1
        , aeEventData = eventData
        , aeMetadata = metadata
        , aeSequenceNumber = seqNum
        , aeOccurredAt = currentTime
        , aeCreatedAt = currentTime
        }
  atomicModifyIORef' eventStoreRef (\es -> (event : es, ()))
  pure (Right event)

-- | Get all events for an account
getEvents :: Int64 -> IO [AccountingEvent]
getEvents accountId = do
  events <- readIORef eventStoreRef
  pure $ filter (\e -> aeAggregateId e == accountId) (reverse events)

-- | Get events from a specific sequence number
getEventsFrom :: Int64 -> Int64 -> IO [AccountingEvent]
getEventsFrom accountId fromSeq = do
  events <- getEvents accountId
  pure $ filter (\e -> aeSequenceNumber e >= fromSeq) events

-- | Replay all events for an account to reconstruct state
replayAccount :: Int64 -> IO (Either Text Double)
replayAccount accountId = do
  events <- getEvents accountId
  case events of
    [] -> pure (Left "No events found for account")
    _ -> do
      let balance = foldl applyEventToBalance 0.0 events
      pure (Right balance)

-- | Get the latest sequence number for an account
getLatestSequence :: Int64 -> IO Int64
getLatestSequence accountId = do
  events <- getEvents accountId
  pure $ foldr (\e n -> max (aeSequenceNumber e) n) 0 events

-- | Apply a single event to compute running balance
applyEventToBalance :: Double -> AccountingEvent -> Double
applyEventToBalance balance event =
  case aeEventType event of
    AccountCreated -> fromMaybe balance (edNewBalance (aeEventData event))
    JournalEntryPosted -> balance + fromMaybe 0.0 (edChangeAmount (aeEventData event))
    BalanceAdjusted -> fromMaybe balance (edNewBalance (aeEventData event))
    _ -> balance

-- ============================================================================
-- EVENT CREATION HELPERS
-- ============================================================================

-- | Create an AccountCreated event
createAccountCreatedEvent :: Int64 -> Text -> Text -> Int -> Int64 -> Double -> Maybe EventMetadata -> IO AccountingEvent
createAccountCreatedEvent accountId code name accountType currencyId balance metadata = do
  currentTime <- getCurrentTime
  _ <- appendEvent accountId AccountCreated eventData metadata
  pure $ AccountingEvent
    { aeId = nil
    , aeAggregateId = accountId
    , aeAggregateType = "account"
    , aeEventType = AccountCreated
    , aeEventVersion = 1
    , aeEventData = eventData
    , aeMetadata = metadata
    , aeSequenceNumber = 1
    , aeOccurredAt = currentTime
    , aeCreatedAt = currentTime
    }
  where
    eventData = EventData
      { edOldBalance = Nothing
      , edNewBalance = Just balance
      , edChangeAmount = Nothing
      , edAccountCode = Just code
      , edAccountName = Just name
      , edAccountType = Just accountType
      , edCurrencyId = Just currencyId
      , edJournalEntryId = Nothing
      , edDebitAccountId = Nothing
      , edCreditAccountId = Nothing
      , edDescription = Nothing
      , edCustomData = Nothing
      }

-- | Create a JournalEntryPosted event
createJournalEntryEvent :: Int64 -> Int64 -> Int64 -> Int64 -> Double -> Maybe Text -> Maybe EventMetadata -> IO AccountingEvent
createJournalEntryEvent accountId journalEntryId debitAccountId creditAccountId amount description metadata = do
  currentTime <- getCurrentTime
  _ <- appendEvent accountId JournalEntryPosted eventData metadata
  pure $ AccountingEvent
    { aeId = nil
    , aeAggregateId = accountId
    , aeAggregateType = "account"
    , aeEventType = JournalEntryPosted
    , aeEventVersion = 1
    , aeEventData = eventData
    , aeMetadata = metadata
    , aeSequenceNumber = 1
    , aeOccurredAt = currentTime
    , aeCreatedAt = currentTime
    }
  where
    eventData = EventData
      { edOldBalance = Nothing
      , edNewBalance = Nothing
      , edChangeAmount = Just amount
      , edAccountCode = Nothing
      , edAccountName = Nothing
      , edAccountType = Nothing
      , edCurrencyId = Nothing
      , edJournalEntryId = Just journalEntryId
      , edDebitAccountId = Just debitAccountId
      , edCreditAccountId = Just creditAccountId
      , edDescription = description
      , edCustomData = Nothing
      }

-- | Create a BalanceAdjusted event
createBalanceAdjustedEvent :: Int64 -> Double -> Double -> Double -> Maybe Text -> Maybe EventMetadata -> IO AccountingEvent
createBalanceAdjustedEvent accountId oldBalance newBalance changeAmount description metadata = do
  currentTime <- getCurrentTime
  _ <- appendEvent accountId BalanceAdjusted eventData metadata
  pure $ AccountingEvent
    { aeId = nil
    , aeAggregateId = accountId
    , aeAggregateType = "account"
    , aeEventType = BalanceAdjusted
    , aeEventVersion = 1
    , aeEventData = eventData
    , aeMetadata = metadata
    , aeSequenceNumber = 1
    , aeOccurredAt = currentTime
    , aeCreatedAt = currentTime
    }
  where
    eventData = EventData
      { edOldBalance = Just oldBalance
      , edNewBalance = Just newBalance
      , edChangeAmount = Just changeAmount
      , edAccountCode = Nothing
      , edAccountName = Nothing
      , edAccountType = Nothing
      , edCurrencyId = Nothing
      , edJournalEntryId = Nothing
      , edDebitAccountId = Nothing
      , edCreditAccountId = Nothing
      , edDescription = description
      , edCustomData = Nothing
      }