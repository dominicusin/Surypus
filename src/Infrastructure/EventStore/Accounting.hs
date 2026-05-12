-- | Accounting Event Store - Append-only event store for accounting operations
-- Implements US-3-1: Event-sourced accounting with replay capability
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}
module Infrastructure.EventStore.Accounting
  ( AccountingEvent (..)
  , AccountCreated (..)
  , JournalEntryPosted (..)
  , EntryReverted (..)
  , EntryCancelled (..)
  , AccountFrozen (..)
  , AccountUnfrozen (..)
  , AccountingEventStore (..)
  , mkAccountingEventStore
  , appendAccountingEvent
  , readAccountEvents
  , replayAccountEvents
  , reconstructAccountBalance
  , AccountSnapshot (..)
  , projectCurrentState
  ) where

import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import Data.Time (Day, UTCTime, getCurrentTime)
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as M
import qualified Data.List as L
import Data.IORef (IORef, newIORef, readIORef, modifyIORef')
import GHC.Generics (Generic)

-- | Accounting event types - every state change captured as an event
data AccountingEvent
  = AccountCreatedEvent AccountCreated
  | JournalEntryPostedEvent JournalEntryPosted
  | EntryRevertedEvent EntryReverted
  | EntryCancelledEvent EntryCancelled
  | AccountFrozenEvent AccountFrozen
  | AccountUnfrozenEvent AccountUnfrozen
  deriving (Show, Eq, Generic)

-- | Account created event payload
data AccountCreated = AccountCreated
  { acAccountId :: Int64
  , acCode :: Text
  , acName :: Text
  , acType :: Text
  , acParentId :: Maybe Int64
  , acTimestamp :: UTCTime
  } deriving (Show, Eq, Generic)

-- | Journal entry posted event payload
data JournalEntryPosted = JournalEntryPosted
  { jepEntryId :: Int64
  , jepDebitAcc :: Int64
  , jepCreditAcc :: Int64
  , jepAmount :: Double
  , jepCurrency :: Text
  , jepDescription :: Text
  , jepDate :: Day
  , jepTimestamp :: UTCTime
  } deriving (Show, Eq, Generic)

-- | Entry reverted event payload
data EntryReverted = EntryReverted
  { ervOriginalEntryId :: Int64
  , ervRevertedById :: Int64
  , ervReason :: Text
  , ervTimestamp :: UTCTime
  } deriving (Show, Eq, Generic)

-- | Entry cancelled event payload
data EntryCancelled = EntryCancelled
  { ecOriginalEntryId :: Int64
  , ecCancelledById :: Int64
  , ecReason :: Text
  , ecTimestamp :: UTCTime
  } deriving (Show, Eq, Generic)

-- | Account frozen event payload
data AccountFrozen = AccountFrozen
  { afAccountId :: Int64
  , afFrozenById :: Int64
  , afReason :: Text
  , afTimestamp :: UTCTime
  } deriving (Show, Eq, Generic)

-- | Account unfrozen event payload
data AccountUnfrozen = AccountUnfrozen
  { ufAccountId :: Int64
  , ufUnfrozenById :: Int64
  , ufReason :: Text
  , ufTimestamp :: UTCTime
  } deriving (Show, Eq, Generic)

-- | Projected account state (result of replay)
data AccountSnapshot = AccountSnapshot
  { asAccountId :: Int64
  , asCode :: Text
  , asName :: Text
  , asType :: Text
  , asDebitTotal :: Double
  , asCreditTotal :: Double
  , asBalance :: Double
  , asIsFrozen :: Bool
  , asEntryCount :: Int
  } deriving (Show, Eq, Generic)

-- | Event store for accounting events
data AccountingEventStore = AccountingEventStore
  { aesEvents :: IORef [AccountingEvent]
  , aesStreamName :: Text
  }

-- | Create a new accounting event store
mkAccountingEventStore :: Text -> IO AccountingEventStore
mkAccountingEventStore streamName = do
  ref <- newIORef []
  pure $ AccountingEventStore
    { aesEvents = ref
    , aesStreamName = streamName
    }

-- | Append an event to the store
appendAccountingEvent :: AccountingEventStore -> AccountingEvent -> IO ()
appendAccountingEvent store event =
  modifyIORef' (aesEvents store) (\es -> es ++ [event])

-- | Read all events for an account stream
readAccountEvents :: AccountingEventStore -> IO [AccountingEvent]
readAccountEvents store = readIORef (aesEvents store)

-- | Replay events to reconstruct account state
replayAccountEvents :: [AccountingEvent] -> Map Int64 AccountSnapshot
replayAccountEvents events =
  L.foldl' applyEvent M.empty events

-- | Apply a single event to current state
applyEvent :: Map Int64 AccountSnapshot -> AccountingEvent -> Map Int64 AccountSnapshot
applyEvent state (AccountCreatedEvent ev) =
  M.insert (acAccountId ev) AccountSnapshot
    { asAccountId = acAccountId ev
    , asCode = acCode ev
    , asName = acName ev
    , asType = acType ev
    , asDebitTotal = 0
    , asCreditTotal = 0
    , asBalance = 0
    , asIsFrozen = False
    , asEntryCount = 0
    } state
applyEvent state (JournalEntryPostedEvent ev) =
  M.adjust updateDebit (jepDebitAcc ev) $
  M.adjust updateCredit (jepCreditAcc ev) state
  where
    updateDebit snap = snap
      { asDebitTotal = asDebitTotal snap + jepAmount ev
      , asBalance = asBalance snap + jepAmount ev
      , asEntryCount = asEntryCount snap + 1
      }
    updateCredit snap = snap
      { asCreditTotal = asCreditTotal snap + jepAmount ev
      , asBalance = asBalance snap - jepAmount ev
      , asEntryCount = asEntryCount snap + 1
      }
applyEvent state (EntryRevertedEvent _ev) = state
applyEvent state (EntryCancelledEvent _ev) = state
applyEvent state (AccountFrozenEvent ev) =
  M.adjust (\snap -> snap { asIsFrozen = True }) (afAccountId ev) state
applyEvent state (AccountUnfrozenEvent ev) =
  M.adjust (\snap -> snap { asIsFrozen = False }) (ufAccountId ev) state

-- | Reconstruct a single account balance from its events
reconstructAccountBalance :: Int64 -> [AccountingEvent] -> Maybe AccountSnapshot
reconstructAccountBalance accountId events =
  M.lookup accountId (replayAccountEvents events)

-- | Project current state from all events
projectCurrentState :: AccountingEventStore -> IO (Map Int64 AccountSnapshot)
projectCurrentState store = do
  events <- readAccountEvents store
  pure $ replayAccountEvents events