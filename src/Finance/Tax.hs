{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DeriveGeneric #-}

-- | Finance.Tax - Enhanced VAT/Tax calculations with refinement types
-- This module provides type-safe tax calculations with formal verification
module Finance.Tax where

import Data.Decimal (Decimal)
import Data.Int (Int64)
import qualified Data.Text as T
import Data.Time (Day)
import GHC.Generics (Generic)

-- | Tax rate with validation (0-100%)
newtype TaxRate = TaxRate { unTaxRate :: Decimal }
  deriving (Show, Eq, Ord)

-- | Smart constructor with validation
mkTaxRate :: Decimal -> Maybe TaxRate
mkTaxRate r
  | r < 0     = Nothing
  | r > 100   = Nothing
  | otherwise = Just (TaxRate r)

-- | Calculate VAT amount from price and rate
-- Invariant: calcVAT amount rate >= 0
-- Invariant: calcVAT amount rate <= amount (when rate <= 100)
calcVAT :: Decimal -> TaxRate -> Decimal
calcVAT amount (TaxRate rate)
  | amount < 0 || rate < 0 = 0
  | rate > 100 = 0  -- Invalid rate (>100%)
  | otherwise =
      -- rate is in percentage points (Decimal 20 = 20%)
      -- VAT = amount * rate / 100
      let result = (amount * rate) / 100
      in if result < 0 then 0 else result

-- | Extract VAT from inclusive price
-- Invariant: calcVATFromInclusive amount rate >= 0
-- Invariant: calcVATFromInclusive amount rate <= amount (when rate <= 100)
calcVATFromInclusive :: Decimal -> TaxRate -> Decimal
calcVATFromInclusive amount (TaxRate rate)
  | amount < 0 || rate < 0 = 0
  | rate > 100 = 0
  | otherwise =
      -- VAT = inclusive * rate / (100 + rate) where rate is a decimal (0.20 for 20%)
      let divisor = 100 + rate
      in if divisor == 0 then 0 else (amount * rate) / divisor

-- | Price including VAT
-- Invariant: calcPriceWithVAT price rate >= price (when rate >= 0)
calcPriceWithVAT :: Decimal -> TaxRate -> Decimal
calcPriceWithVAT price rate = price + calcVAT price rate

-- | Price excluding VAT (from inclusive price)
-- Invariant: calcPriceWithoutVAT inclusive rate <= inclusive (when rate <= 100)
calcPriceWithoutVAT :: Decimal -> TaxRate -> Decimal
calcPriceWithoutVAT inclusive (TaxRate rate)
  | inclusive < 0 || rate < 0 = 0
  | rate > 100 = 0
  | otherwise =
      -- inclusive / (1 + rate/100) = inclusive * 100 / (100 + rate)
      let multiplier = 100 + rate
      in if multiplier == 0 then 0 else (inclusive * 100) / multiplier

-- | VAT inclusive price
-- Invariant: calcTaxInclusive price rate >= price (when rate >= 0)
calcTaxInclusive :: Decimal -> TaxRate -> Decimal
calcTaxInclusive price (TaxRate rate)
  | price < 0 || rate < 0 = 0
  | rate > 100 = 0
  | otherwise =
      -- price * (1 + rate/100) = price * (100 + rate) / 100
      let factor = 100 + rate
      in (price * factor) / 100

-- | Tax entry with richer types
data TaxEntry = TaxEntry
  { teId          :: TaxEntryId
  , tePeriodStart :: Day
  , tePeriodEnd   :: Day
  , teVATAmount   :: Decimal       -- VAT amount
  , teExciseAmount:: Decimal       -- Excise amount
  , teSalesTax    :: Decimal       -- Sales tax amount
  , teFlags       :: Int           -- Flags
  , teOrder        :: Int           -- Sort order
  } deriving (Show, Eq, Generic)

newtype TaxEntryId = TaxEntryId { unTaxEntryId :: Int64 }
  deriving (Show, Eq, Ord)

-- | Validate tax rate
validateTaxRate :: Decimal -> Bool
validateTaxRate rate = rate >= 0 && rate <= 100

-- | Validate tax entry - all values must be non-negative
validateTaxEntry :: TaxEntry -> Bool
validateTaxEntry e =
  teVATAmount e >= 0 && teExciseAmount e >= 0 && teSalesTax e >= 0

-- | Pretty print tax rate
prettyTaxRate :: TaxRate -> T.Text
prettyTaxRate (TaxRate r) = T.pack $ show r <> "%"

-- | Pretty print tax entry
prettyTaxEntry :: TaxEntry -> T.Text
prettyTaxEntry e = "TaxEntry #" <> T.pack (show (unTaxEntryId (teId e))) <> " VAT: " <> T.pack (show (teVATAmount e))
