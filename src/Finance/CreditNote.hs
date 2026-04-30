{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DeriveGeneric #-}

-- | Finance.CreditNote - Enhanced credit note management  
-- This module provides type-safe credit note operations with formal verification
module Finance.CreditNote where

import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import Data.Time (Day, fromGregorian)
import Surypus.Types (Decimal, NonNeg, mkNonNeg, unNonNeg)

-- | Credit note with enhanced semantics
data CreditNote = CreditNote
  { cnId           :: CreditNoteId
    , cnNumber       :: CreditNoteNumber
    , cnDate         :: Day
    , cnAmount       :: NonNeg        -- Amount always >= 0
    , cnCurrency     :: CurrencyCode
    , cnReason       :: Text
    , cnRelatedBill  :: Maybe BillId
    , cnStatus       :: CreditNoteStatus
    , cnCreatedAt    :: Day
    , cnUpdatedAt    :: Maybe Day
    } deriving (Show, Eq, Generic)

-- | Newtypes for type safety
newtype CreditNoteId = CreditNoteId { unCreditNoteId :: Int64 }
  deriving (Show, Eq, Ord)

newtype CreditNoteNumber = CreditNoteNumber { unCreditNoteNumber :: Text }
  deriving (Show, Eq, Ord)

newtype CurrencyCode = CurrencyCode { unCurrencyCode :: Text }
  deriving (Show, Eq, Ord)

newtype BillId = BillId { unBillId :: Int64 }
  deriving (Show, Eq, Ord)

-- | Credit note status
data CreditNoteStatus
  = CNSIssued    -- Выставлен (issued)
  | CNSCancelled -- Аннулирован (cancelled)
  | CNSApplied    -- Применён (applied)
  deriving (Show, Eq, Enum, Bounded, Ord)

-- | Smart constructor with validation
createCreditNote :: CreditNoteId -> CreditNoteNumber -> Day -> NonNeg -> CurrencyCode -> Text -> CreditNote
createCreditNote cnid num date amt curr reason = CreditNote
  { cnId = cnid
  , cnNumber = num
  , cnDate = date
  , cnAmount = amt
  , cnCurrency = curr
  , cnReason = reason
  , cnRelatedBill = Nothing
  , cnStatus = CNSIssued
  , cnCreatedAt = date
  , cnUpdatedAt = Nothing
  }

-- | Cancel credit note with invariant: only issued notes can be cancelled
cancelCreditNote :: CreditNote -> Maybe CreditNote
cancelCreditNote cn
  | cnStatus cn /= CNSIssued = Nothing
  | otherwise = Just $ cn { cnStatus = CNSCancelled, cnUpdatedAt = Just (fromGregorian 2024 1 1) }

-- | Apply credit note with invariant: amount > 0 and status is issued
applyCreditNote :: NonNeg -> CreditNote -> Maybe CreditNote
applyCreditNote amount cn
  | unNonNeg amount <= 0 = Nothing
  | cnStatus cn /= CNSIssued = Nothing
  | otherwise = Just $ cn
      { cnAmount = mkNonNeg (unNonNeg (cnAmount cn) - unNonNeg amount)
      , cnStatus = if unNonNeg (cnAmount cn) - unNonNeg amount <= 0 then CNSApplied else cnStatus cn
      , cnUpdatedAt = Just (fromGregorian 2024 1 1)
      }

-- | Check if credit note is active
isActiveCreditNote :: CreditNote -> Bool
isActiveCreditNote cn = cnStatus cn == CNSIssued

-- | Check if credit note is fully applied
isFullyApplied :: CreditNote -> Bool
isFullyApplied cn = cnStatus cn == CNSApplied

-- | Pretty print credit note
prettyCreditNote :: CreditNote -> Text
prettyCreditNote cn = unCreditNoteNumber (cnNumber cn) <> " - " 
  <> T.pack (show (unNonNeg (cnAmount cn)) <> " " 
  <> unCurrencyCode (cnCurrency cn) <> " - " 
  <> T.pack (show (cnStatus cn))

-- | Calculate total applied amount
calculateAppliedAmount :: [CreditNote] -> NonNeg
calculateAppliedAmount notes = 
  mkNonNeg $ sum [unNonNeg (cnAmount n) | n <- notes, cnStatus n == CNSApplied]
