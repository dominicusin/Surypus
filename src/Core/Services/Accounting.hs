-- | Accounting Service - Orchestrates event-sourced accounting operations
-- Implements double-entry bookkeeping with event sourcing for audit trail
{-# LANGUAGE OverloadedStrings #-}
module Core.Services.Accounting
  ( processTransactionWithEvents
  , processTransactionWithEvents'
  , postJournalEntry
  , revertJournalEntry
  , freezeAccount
  , unfreezeAccount
  , getAccountSnapshot
  , getFullState
  ) where

import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import Data.Time (Day, UTCTime, getCurrentTime)
import Data.Map.Strict (Map)
import Finance.Accounting
import Infrastructure.EventStore.Accounting
import Surypus.Types (unDecimal)

-- | Process a transaction and emit events to the event store
processTransactionWithEvents :: AccountingEventStore -> Transaction -> IO (Either Text ())
processTransactionWithEvents store tx = do
  case validateTransaction tx of
    Left err -> pure $ Left err
    Right validTx -> do
      now <- getCurrentTime
      let txIdVal = maybe 0 id (txId validTx)
      mapM_ (emitEntryEvent store now txIdVal) (txEntries validTx)
      pure $ Right ()

-- | Process transaction with events, returning the events emitted
processTransactionWithEvents' :: AccountingEventStore -> Transaction -> IO (Either Text [AccountingEvent])
processTransactionWithEvents' store tx = do
  case validateTransaction tx of
    Left err -> pure $ Left err
    Right validTx -> do
      now <- getCurrentTime
      let txIdVal = maybe 0 id (txId validTx)
      events <- mapM (emitEntryEvent' store now txIdVal) (txEntries validTx)
      pure $ Right events

-- | Post a journal entry and emit event
postJournalEntry :: AccountingEventStore -> Int64 -> Int64 -> Int64 -> Double -> Text -> Day -> IO ()
postJournalEntry store entryId debitAcc creditAcc amount currency date = do
  now <- getCurrentTime
  let event = JournalEntryPostedEvent JournalEntryPosted
        { jepEntryId = entryId
        , jepDebitAcc = debitAcc
        , jepCreditAcc = creditAcc
        , jepAmount = amount
        , jepCurrency = currency
        , jepDescription = "Journal entry #" <> T.pack (show entryId)
        , jepDate = date
        , jepTimestamp = now
        }
  appendAccountingEvent store event

-- | Revert a journal entry
revertJournalEntry :: AccountingEventStore -> Int64 -> Int64 -> Text -> IO ()
revertJournalEntry store originalEntryId revertedById reason = do
  now <- getCurrentTime
  let event = EntryRevertedEvent EntryReverted
        { ervOriginalEntryId = originalEntryId
        , ervRevertedById = revertedById
        , ervReason = reason
        , ervTimestamp = now
        }
  appendAccountingEvent store event

-- | Freeze an account
freezeAccount :: AccountingEventStore -> Int64 -> Int64 -> Text -> IO ()
freezeAccount store accountId frozenById reason = do
  now <- getCurrentTime
  let event = AccountFrozenEvent AccountFrozen
        { afAccountId = accountId
        , afFrozenById = frozenById
        , afReason = reason
        , afTimestamp = now
        }
  appendAccountingEvent store event

-- | Unfreeze an account
unfreezeAccount :: AccountingEventStore -> Int64 -> Int64 -> Text -> IO ()
unfreezeAccount store accountId unfrozenById reason = do
  now <- getCurrentTime
  let event = AccountUnfrozenEvent AccountUnfrozen
        { ufAccountId = accountId
        , ufUnfrozenById = unfrozenById
        , ufReason = reason
        , ufTimestamp = now
        }
  appendAccountingEvent store event

-- | Get current snapshot for an account
getAccountSnapshot :: AccountingEventStore -> Int64 -> IO (Maybe AccountSnapshot)
getAccountSnapshot store accountId = do
  events <- readAccountEvents store
  pure $ reconstructAccountBalance accountId events

-- | Get full projected state
getFullState :: AccountingEventStore -> IO (Map Int64 AccountSnapshot)
getFullState store = projectCurrentState store

-- Internal helpers

emitEntryEvent :: AccountingEventStore -> UTCTime -> Int64 -> LedgerEntry -> IO ()
emitEntryEvent store now newTxId entry = do
   let event = mkEvent entry
   appendAccountingEvent store event
   where
     mkEvent e = JournalEntryPostedEvent JournalEntryPosted
       { jepEntryId = maybe newTxId id (leId e)
       , jepDebitAcc = fromIntegral (leAccount e)
       , jepCreditAcc = fromIntegral (leAccount e)
       , jepAmount = unDecimal (leDebit e)
       , jepCurrency = "RUB"
       , jepDescription = leDescription e
       , jepDate = leDate e
       , jepTimestamp = now
       }

emitEntryEvent' :: AccountingEventStore -> UTCTime -> Int64 -> LedgerEntry -> IO AccountingEvent
emitEntryEvent' store now newTxId' entry = do
   let event = mkEvent entry
   appendAccountingEvent store event
   pure event
   where
     mkEvent e = JournalEntryPostedEvent JournalEntryPosted
       { jepEntryId = maybe newTxId' id (leId e)
       , jepDebitAcc = fromIntegral (leAccount e)
       , jepCreditAcc = fromIntegral (leAccount e)
       , jepAmount = unDecimal (leDebit e)
       , jepCurrency = "RUB"
       , jepDescription = leDescription e
       , jepDate = leDate e
       , jepTimestamp = now
       }