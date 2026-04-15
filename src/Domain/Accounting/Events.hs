{-# LANGUAGE DeriveGeneric #-}

module Domain.Accounting.Events where

import Data.Aeson (FromJSON, ToJSON)
import qualified Data.Aeson as Aeson
import Data.Int (Int64)
import Data.Maybe (fromMaybe)
import Data.Text (Text)
import Data.Time (UTCTime)
import GHC.Generics (Generic)

-- Events (immutable, append-only)
data AccountingEvent
  = EntryCreated
      { entryId :: Int64,
        billId :: Int64,
        account :: Text,
        debit :: Double,
        credit :: Double,
        description :: Text,
        timestamp :: UTCTime
      }
  | EntryPosted
      { entryId :: Int64,
        billId :: Int64,
        timestamp :: UTCTime
      }
  | BillPosted
      { billId :: Int64,
        totalDebit :: Double,
        totalCredit :: Double,
        timestamp :: UTCTime
      }
  | BillCancelled
      { billId :: Int64,
        cancelledBy :: Int64,
        reason :: Text,
        timestamp :: UTCTime
      }
  deriving (Show, Eq, Generic)

instance ToJSON AccountingEvent

instance FromJSON AccountingEvent

-- Apply a single event to a running balance for a given account code
-- This is a pure builder used by read-model replay logic
applyEvent :: Text -> Double -> AccountingEvent -> Double
applyEvent accountCode bal ev = case ev of
  EntryCreated {account = acc, debit = d, credit = c}
    | acc == accountCode -> bal + d - c
  _ -> bal

-- | Rebuild balance for an account from a list of events
rebuildBalance :: Text -> [AccountingEvent] -> Double
rebuildBalance code events = foldl (applyEvent code) 0 events
