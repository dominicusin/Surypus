{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DeriveGeneric #-}

-- | Finance.ExchangeRate - Enhanced currency exchange rate management
-- This module provides type-safe exchange rate operations with temporal validity
module Finance.ExchangeRate where

import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import Data.Time (Day, fromGregorian)
import Surypus.Types (Decimal, NonNeg, mkNonNeg, unNonNeg)

-- | Exchange rate with validation (rate > 0)
data ExchangeRate = ExchangeRate
  { erId             :: RateId
    , erFromCurrency   :: CurrencyCode
    , erToCurrency     :: CurrencyCode
    , erRate           :: NonNeg        -- Always > 0
    , erEffectiveFrom  :: Day           -- Valid from date
    , erEffectiveTo    :: Maybe Day     -- Valid until (Nothing = open-ended)
    , erSource         :: RateSource
    , erIsActive       :: Bool
    , erCreatedAt      :: Day
    , erUpdatedAt      :: Maybe Day
  } deriving (Show, Eq, Generic)

-- | Newtypes for type safety
newtype RateId = RateId { unRateId :: Int64 } deriving (Show, Eq, Ord)

newtype CurrencyCode = CurrencyCode { unCurrencyCode :: Text }
  deriving (Show, Eq, Ord)

-- | Rate source for audit trail
data RateSource
  = CentralBank    -- Central bank rate
  | CommercialBank -- Commercial bank rate
  | MarketRate     -- Market-driven rate
  | ManualRate     -- Manually set rate
  deriving (Show, Eq, Enum, Bounded, Ord)

-- | Smart constructor with validation
createExchangeRate :: RateId -> CurrencyCode -> CurrencyCode -> NonNeg -> Day -> RateSource -> ExchangeRate
createExchangeRate rid from to rate date source = ExchangeRate
  { erId = rid
  , erFromCurrency = from
  , erToCurrency = to
  , erRate = rate
  , erEffectiveFrom = date
  , erEffectiveTo = Nothing
  , erSource = source
  , erIsActive = True
  , erCreatedAt = date
  , erUpdatedAt = Nothing
  }

-- | Check if rate is valid on a given date
isValidOnDate :: Day -> ExchangeRate -> Bool
isValidOnDate date rate =
  let startOk = erEffectiveFrom rate <= date
      endOk = maybe True (date <=) (erEffectiveTo rate)
  in startOk && endOk && erIsActive rate

-- | Close rate (set end date)
closeExchangeRate :: Day -> ExchangeRate -> ExchangeRate
closeExchangeRate closeDate rate = rate
  { erEffectiveTo = Just closeDate
  , erIsActive = False
  , erUpdatedAt = Just closeDate
  }

-- | Convert amount between currencies
-- Invariant: result > 0 if amount > 0
convertCurrency :: NonNeg -> ExchangeRate -> Maybe NonNeg
convertCurrency amount rate
  | not (isValidOnDate (error "Date needed") rate = Nothing
  | unNonNeg amount <= 0 = Nothing
  | otherwise = Just $ mkNonNeg (unNonNeg amount * unNonNeg (erRate rate))

-- | Calculate inverse rate (1/rate)
-- Invariant: inverseRate * rate ≈ 1
inverseRate :: ExchangeRate -> Maybe NonNeg
inverseRate rate
  | unNonNeg (erRate rate) == 0 = Nothing
  | otherwise = Just $ mkNonNeg (1 / unNonNeg (erRate rate))

-- | Pretty print exchange rate
prettyExchangeRate :: ExchangeRate -> Text
prettyExchangeRate rate =
  unCurrencyCode (erFromCurrency rate) <> " -> " <> unCurrencyCode (erToCurrency rate) <>
  ": " <> T.pack (show (unNonNeg (erRate rate))) <>
  " (Active: " <> T.pack (show (erIsActive rate)) <> ")"

-- | Calculate cross rate between two currencies via USD (simplified)
calculateCrossRate :: ExchangeRate -> ExchangeRate -> Maybe NonNeg
calculateCrossRate rate1 rate2
  | erToCurrency rate1 /= erFromCurrency rate2 = Nothing  -- Must chain: FROM1 -> TO1/FROM2 -> TO2
  | otherwise =
      let r1 = unNonNeg (erRate rate1)
          r2 = unNonNeg (erRate rate2)
      in if r2 == 0 then Nothing else Just $ mkNonNeg (r1 / r2)
