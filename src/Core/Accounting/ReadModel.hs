-- ============================================================================
-- SURYPUS ACCOUNTING READ MODEL
-- US-3-2: Account read-model replay from event stream
-- ============================================================================

{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE RecordWildCards #-}

module Core.Accounting.ReadModel
  ( -- * Read Model Types
    AccountReadModel(..)
  , BalanceState(..)

    -- * Read Model Operations
  , replayAccountEvents
  , rebuildAccountBalance
  , getCurrentBalance
  , getAccountReadModel

    -- * Event Application
  , applyEvent
  , applyAccountCreated
  , applyJournalEntryPosted
  , applyBalanceAdjusted
  ) where

import Data.Time (UTCTime)
import Data.Int (Int64)
import Data.Text (Text)
import Data.Foldable (foldl')
import Data.Maybe (fromMaybe)
import GHC.Generics (Generic)
import qualified DAL.EventStore as ES

-- ============================================================================
-- READ MODEL TYPES
-- ============================================================================

-- | Balance state for an account
data BalanceState = BalanceState
  { bsAccountId :: Int64
  , bsCurrentBalance :: Double
  , bsDebitTotal :: Double
  , bsCreditTotal :: Double
  , bsLastUpdated :: UTCTime
  , bsEventCount :: Int
  } deriving (Show, Eq, Generic)

-- | Account read model containing all calculated state
data AccountReadModel = AccountReadModel
  { armAccountId :: Int64
  , armCode :: Maybe Text
  , armName :: Maybe Text
  , armAccountType :: Maybe Int
  , armCurrencyId :: Maybe Int64
  , armBalanceState :: BalanceState
  , armCreatedAt :: UTCTime
  , armUpdatedAt :: UTCTime
  } deriving (Show, Eq, Generic)

-- ============================================================================
-- EVENT APPLICATION
-- ============================================================================

-- | Apply a single event to the read model
applyEvent :: AccountReadModel -> ES.AccountingEvent -> AccountReadModel
applyEvent model event
  | ES.aeEventType event == ES.AccountCreated = applyAccountCreated model event
  | ES.aeEventType event == ES.JournalEntryPosted = applyJournalEntryPosted model event
  | ES.aeEventType event == ES.BalanceAdjusted = applyBalanceAdjusted model event
  | otherwise = model

-- | Apply AccountCreated event
applyAccountCreated :: AccountReadModel -> ES.AccountingEvent -> AccountReadModel
applyAccountCreated model event = model
  { armAccountId = ES.aeAggregateId event
  , armCode = ES.edAccountCode (ES.aeEventData event)
  , armName = ES.edAccountName (ES.aeEventData event)
  , armAccountType = ES.edAccountType (ES.aeEventData event)
  , armCurrencyId = ES.edCurrencyId (ES.aeEventData event)
  , armBalanceState = BalanceState
      { bsAccountId = ES.aeAggregateId event
      , bsCurrentBalance = fromMaybe 0.0 (ES.edNewBalance (ES.aeEventData event))
      , bsDebitTotal = 0.0
      , bsCreditTotal = 0.0
      , bsLastUpdated = ES.aeOccurredAt event
      , bsEventCount = 1
      }
  , armCreatedAt = ES.aeOccurredAt event
  , armUpdatedAt = ES.aeOccurredAt event
  }

-- | Apply JournalEntryPosted event
applyJournalEntryPosted :: AccountReadModel -> ES.AccountingEvent -> AccountReadModel
applyJournalEntryPosted model event = model
  { armBalanceState = newBalanceState
  , armUpdatedAt = ES.aeOccurredAt event
  }
  where
    eventData = ES.aeEventData event
    changeAmount = fromMaybe 0.0 (ES.edChangeAmount eventData)
    oldState = armBalanceState model
    newBalanceState = oldState
      { bsCurrentBalance = bsCurrentBalance oldState + changeAmount
      , bsDebitTotal = if changeAmount > 0
                      then bsDebitTotal oldState + changeAmount
                      else bsDebitTotal oldState
      , bsCreditTotal = if changeAmount < 0
                       then bsCreditTotal oldState + abs changeAmount
                       else bsCreditTotal oldState
      , bsLastUpdated = ES.aeOccurredAt event
      , bsEventCount = bsEventCount oldState + 1
      }

-- | Apply BalanceAdjusted event
applyBalanceAdjusted :: AccountReadModel -> ES.AccountingEvent -> AccountReadModel
applyBalanceAdjusted model event = model
  { armBalanceState = newBalanceState
  , armUpdatedAt = ES.aeOccurredAt event
  }
  where
    eventData = ES.aeEventData event
    newBalance = fromMaybe 0.0 (ES.edNewBalance eventData)
    changeAmount = fromMaybe 0.0 (ES.edChangeAmount eventData)
    oldState = armBalanceState model
    newBalanceState = oldState
      { bsCurrentBalance = newBalance
      , bsDebitTotal = if changeAmount > 0
                      then bsDebitTotal oldState + changeAmount
                      else bsDebitTotal oldState
      , bsCreditTotal = if changeAmount < 0
                       then bsCreditTotal oldState + abs changeAmount
                       else bsCreditTotal oldState
      , bsLastUpdated = ES.aeOccurredAt event
      , bsEventCount = bsEventCount oldState + 1
      }

-- ============================================================================
-- READ MODEL OPERATIONS
-- ============================================================================

-- | Create initial model from the first event in a list
mkInitialModel :: Int64 -> [ES.AccountingEvent] -> AccountReadModel
mkInitialModel accountId events =
  let firstEvent = head events
      ts = ES.aeOccurredAt firstEvent
  in AccountReadModel
    { armAccountId = accountId
    , armCode = Nothing
    , armName = Nothing
    , armAccountType = Nothing
    , armCurrencyId = Nothing
    , armBalanceState = BalanceState
        { bsAccountId = accountId
        , bsCurrentBalance = 0.0
        , bsDebitTotal = 0.0
        , bsCreditTotal = 0.0
        , bsLastUpdated = ts
        , bsEventCount = 0
        }
    , armCreatedAt = ts
    , armUpdatedAt = ts
    }

-- | Replay events from the event store to build read model
replayAccountEvents :: Int64 -> IO (Either Text AccountReadModel)
replayAccountEvents accountId = do
  events <- ES.getEvents accountId
  case events of
    [] -> pure (Left "No events found for account")
    es -> do
      let initialModel = mkInitialModel accountId es
          finalModel = foldl' applyEvent initialModel es
      pure (Right finalModel)

-- | Rebuild account balance from event stream
rebuildAccountBalance :: Int64 -> IO (Either Text Double)
rebuildAccountBalance accountId = do
  result <- replayAccountEvents accountId
  case result of
    Left err -> pure (Left err)
    Right model -> pure (Right (bsCurrentBalance (armBalanceState model)))

-- | Get current balance for an account
getCurrentBalance :: Int64 -> IO (Either Text Double)
getCurrentBalance = rebuildAccountBalance

-- | Get full account read model
getAccountReadModel :: Int64 -> IO (Either Text AccountReadModel)
getAccountReadModel = replayAccountEvents

-- ============================================================================
-- VALIDATION
-- ============================================================================

-- | Validate that the read model is in a consistent state
validateReadModel :: AccountReadModel -> Either Text ()
validateReadModel model
  | bsCurrentBalance balanceState < 0 = Left "Account balance cannot be negative"
  | bsEventCount balanceState == 0 = Left "Account has no events"
  | otherwise = Right ()
  where
    balanceState = armBalanceState model