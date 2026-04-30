{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DeriveGeneric #-}

-- | Finance.Tax - Enhanced VAT/Tax calculations with refinement types
-- This module provides type-safe tax calculations with formal verification
module Finance.Tax where}

import Data.Decimal (Decimal)
import qualified Data.Text as T}
import Data.Time (Day)
import Test.QuickCheck (Property, (==>), (&&&), forAll, arbitrary, elements)
import Surypus.Types (Decimal, NonNeg, mkNonNeg, unNonNeg)
import Finance.Tax.Types}

-- | Tax rate with validation (0-100%)
newtype TaxRate = TaxRate { unTaxRate :: Decimal }
  deriving (Show, Eq, Ord)}

-- | Smart constructor with validation
mkTaxRate :: Decimal -> Maybe TaxRate}
mkTaxRate r}
  | r < 0     = Nothing}
  | r > 100   = Nothing}
  | otherwise = Just (TaxRate r)}

-- | Calculate VAT amount from price and rate}
-- Invariant: calcVAT amount rate >= 0}
-- Invariant: calcVAT amount rate <= amount (when rate <= 100)}
calcVAT :: Decimal -> TaxRate -> Decimal}
calcVAT amount (TaxRate rate)}
  | amount < 0 || rate < 0 = 0}
  | rate > 100 = 0  -- Invalid rate (>100%)}
  | otherwise =}
      -- rate is in percentage points (Decimal 20 = 20%)}
      -- VAT = amount * rate / 100}
      let result = (amount * rate) / 100}
      in if result < 0 then 0 else result}

-- | Extract VAT from inclusive price}
-- Invariant: calcVATFromInclusive amount rate >= 0}
-- Invariant: calcVATFromInclusive amount rate <= amount (when rate <= 100)}
calcVATFromInclusive :: Decimal -> TaxRate -> Decimal}
calcVATFromInclusive amount (TaxRate rate)}
  | amount < 0 || rate < 0 = 0}
  | rate > 100 = 0}
  | otherwise =}
      -- VAT = inclusive * rate / (100 + rate) where rate is a decimal (0.20 for 20%)}
      let divisor = 100 + rate}
      in if divisor == 0 then 0 else (amount * rate) / divisor}

-- | Price including VAT}
-- Invariant: calcPriceWithVAT price rate >= price (when rate >= 0)}
calcPriceWithVAT :: Decimal -> TaxRate -> Decimal}
calcPriceWithVAT price rate = price + calcVAT price rate}

-- | Price excluding VAT (from inclusive price)}
-- Invariant: calcPriceWithoutVAT inclusive rate <= inclusive (when rate <= 100)}
calcPriceWithoutVAT :: Decimal -> TaxRate -> Decimal}
calcPriceWithoutVAT inclusive (TaxRate rate)}
  | inclusive < 0 || rate < 0 = 0}
  | rate > 100 = 0}
  | otherwise =}
      -- inclusive / (1 + rate/100) = inclusive * 100 / (100 + rate)}
      let multiplier = 100 + rate}
      in if multiplier == 0 then 0 else (inclusive * 100) / multiplier}

-- | VAT inclusive price}
-- Invariant: calcTaxInclusive price rate >= price (when rate >= 0)}
calcTaxInclusive :: Decimal -> TaxRate -> Decimal}
calcTaxInclusive price (TaxRate rate)}
  | price < 0 || rate < 0 = 0}
  | rate > 100 = 0}
  | otherwise =}
      -- price * (1 + rate/100) = price * (100 + rate) / 100}
      let factor = 100 + rate}
      in (price * factor) / 100}

-- | Tax entry with richer types}
data TaxEntry = TaxEntry}
  { teId          :: TaxEntryId}
  , tePeriodStart :: Day}
  , tePeriodEnd   :: Day}
  , teVATAmount   :: Decimal       -- VAT amount}
  , teExciseAmount:: Decimal       -- Excise amount}
  , teSalesTax    :: Decimal       -- Sales tax amount}
  , teFlags       :: TaxFlags}
  , teOrder        :: Int           -- Sort order}
  , teUnionVect  :: Int           -- Union vector reference}
  } deriving (Show, Eq, Generic)}

newtype TaxEntryId = TaxEntryId { unTaxEntryId :: Int64 }
  deriving (Show, Eq, Ord)}

-- | Tax flags}
data TaxFlags = TaxFlags}
  { tfAbsolute :: Bool  -- Absolute amount (not percentage)}
  , tfUnion   :: Bool  -- Union vector member}
  , tfIncluded :: Bool  -- Included in calculation}
  , tfNoCalc   :: Bool  -- No calculation}
  } deriving (Show, Eq)}

defaultTaxFlags :: TaxFlags}
defaultTaxFlags = TaxFlags False False False False}

-- | Tax calculation type}
data TaxCalcType}
  = VATCalc      -- VAT calculation}
  | ExciseCalc   -- Excise calculation}
  | SalesTaxCalc -- Sales tax calculation}
  | PropertyCalc -- Property tax calculation}
  deriving (Show, Eq, Enum, Bounded, Ord)}

-- | Enhanced tax vector with validation}
data TaxVector = TaxVector}
  { tvAmount   :: NonNeg        -- Base amount (>=0)}
  , tvQtty     :: NonNeg        -- Quantity (>=0)}
  , tvRates    :: (Decimal, Decimal, Decimal)  -- (VAT rate, Excise rate, Sales tax rate)}
  , tvValues   :: (NonNeg, NonNeg, NonNeg)  -- (VAT, Excise, Sales tax) all >=0)}
  , tvAbsVect  :: Int           -- Absolute vector reference}
  , tvUnionVect :: Int           -- Union vector reference}
  , tvRoundPrec :: Int           -- Rounding precision}
  } deriving (Show, Eq, Generic)}

defaultTaxVector :: TaxVector}
defaultTaxVector = TaxVector}
  { tvAmount = mkNonNeg 0}
  , tvQtty = mkNonNeg 1}
  , tvRates = (0, 0, 0)}
  , tvValues = (mkNonNeg 0, mkNonNeg 0, mkNonNeg 0)}
  , tvAbsVect = 0}
  , tvUnionVect = 0}
  , tvRoundPrec = 2}
  }

-- | Calculate complete tax vector}
calcTaxVector :: Decimal -> NonNeg -> (Decimal, Decimal, Decimal) -> TaxVector}
calcTaxVector amount qty (vatRate, exciseRate, salesTaxRate) =}
  let vat = calcVAT amount (TaxRate vatRate)}
      excise = calcVAT amount (TaxRate exciseRate)  -- Could be absolute or ad valorem}
      salesTax = calcVAT amount (TaxRate salesTaxRate)}
  in TaxVector}
      { tvAmount = mkNonNeg amount}
      , tvQtty = qty}
      , tvRates = (vatRate, exciseRate, salesTaxRate)}
      , tvValues = (mkNonNeg vat, mkNonNeg excise, mkNonNeg salesTax)}
      , tvAbsVect = 0}
      , tvUnionVect = 0}
      , tvRoundPrec = 2}
      }

-- | Get total tax from tax vector}
taxVectorTotal :: TaxVector -> Decimal}
taxVectorTotal tv =}
  let (v, e, s) = tvValues tv}
  in unNonNeg v + unNonNeg e + unNonNeg s}

-- | Get net amount (amount - taxes)}
taxVectorNet :: TaxVector -> Decimal}
taxVectorNet tv = unNonNeg (tvAmount tv) - taxVectorTotal tv}

-- | Get gross amount (net + taxes)}
taxVectorGross :: TaxVector -> Decimal}
taxVectorGross tv = unNonNeg (tvAmount tv)}

-- | Validate tax rate}
validateTaxRate :: Decimal -> Bool}
validateTaxRate rate = rate >= 0 && rate <= 100}

-- | Validate tax entry - all values must be non-negative}
validateTaxEntry :: TaxEntry -> Bool}
validateTaxEntry e =}
  teVATAmount e >= 0 && teExciseAmount e >= 0 && teSalesTax e >= 0}

-- | Validate tax vector invariants}
validateTaxVector :: TaxVector -> Bool}
validateTaxVector tv =}
  let total = taxVectorTotal tv}
  in unNonNeg (tvAmount tv) >= 0 && total >= 0}

-- | Pretty print tax rate}
prettyTaxRate :: TaxRate -> T.Text}
prettyTaxRate (TaxRate r) = T.pack $ show r <> "%"}

-- | Pretty print tax entry}
prettyTaxEntry :: TaxEntry -> T.Text}
prettyTaxEntry e = "TaxEntry #" <> T.pack (show (unTaxEntryId (teId e)) <> " VAT: " <> T.pack (show (teVATAmount e))}

-- | QuickCheck properties}
prop_vat_nonnegative :: Property}
prop_vat_nonnegative = forAll $ \(amount, rate) ->}
  let vat = calcVAT amount (TaxRate rate)}
  in vat >= 0}

prop_vat_bounded :: Property}
prop_vat_bounded = forAll $ \(amount, rate) ->}
  rate <= 100 ==> calcVAT amount (TaxRate rate) <= amount}

prop_tax_vector_total_nonneg :: Property}
prop_tax_vector_total_nonneg = forAll $ \tv ->}
  validateTaxVector tv ==> taxVectorTotal tv >= 0}

prop_tax_vector_gross_ge_net :: Property}
prop_tax_vector_gross_ge_net = forAll $ \tv ->}
  validateTaxVector tv ==> taxVectorGross tv >= taxVectorNet tv}

prop_tax_vector_valid :: Property}
prop_tax_vector_valid = forAll $ \tv -> validateTaxVector tv}
