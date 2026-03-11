-- | Tax Calculation Module - GTaxVect equivalent from  C++
-- Supports: VAT, Excise, Sales Tax with forward/backward calculation
module Core.Tax where

import Data.Int (Int64)
import Data.Text (Text)
import Test.QuickCheck

-- ============================================================================
-- TAX TYPES
-- ============================================================================

-- | Tax calculation types
data TaxCalcType = TaxCalcType_VAT | TaxCalcType_Excise | TaxCalcType_SalesTax | TaxCalcType_Property
  deriving (Show, Eq, Enum)

-- | Tax flags from C++ GTAXF_*
data TaxFlags = TaxFlags
  { tfAbsolute :: Bool, -- GTAXF_ABSVAT
    tfUnion :: Bool, -- GTAXF_UNION
    tfIncluded :: Bool, -- GTAXF_INCLUDED
    tfNoCalculable :: Bool -- GTAXF_NOCALC
  }
  deriving (Show, Eq)

defaultTaxFlags :: TaxFlags
defaultTaxFlags = TaxFlags False False False False

-- | Tax entry - corresponds to PPGoodsTaxEntry in C++
-- Invariant: All tax values >= 0
data TaxEntry = TaxEntry
  { teTaxGrpId :: Int64, -- Tax group ID
    tePeriodStart :: Int, -- Period start (days since epoch)
    tePeriodEnd :: Int, -- Period end
    teOpId :: Int64, -- Operation ID
    teVAT :: Double, -- VAT rate (0-100)
    teExcise :: Double, -- Excise rate
    teSalesTax :: Double, -- Sales tax rate
    teFlags :: TaxFlags,
    teOrder :: Int, -- Order of application
    teUnionVect :: Int -- Union vector
  }
  deriving (Show, Eq)

-- | Tax vector - corresponds to GTaxVect in C++
data TaxVector = TaxVector
  { tvAmount :: Double, -- Net amount
    tvQtty :: Double, -- Quantity
    tvRates :: (Double, Double, Double, Double), -- (VAT, Excise, SalesTax, Property)
    tvValues :: (Double, Double, Double, Double), -- Calculated values
    tvAbsVect :: Int, -- Absolute vector flags
    tvUnionVect :: Int, -- Union vector
    tvRoundPrec :: Int -- Rounding precision
  }
  deriving (Show, Eq)

defaultTaxVector :: TaxVector
defaultTaxVector =
  TaxVector
    { tvAmount = 0,
      tvQtty = 0,
      tvRates = (0, 0, 0, 0),
      tvValues = (0, 0, 0, 0),
      tvAbsVect = 0,
      tvUnionVect = 0,
      tvRoundPrec = 2
    }

-- | TaxRate - Tax rate
data TaxRate = TaxRate
  { trId :: Int64,
    trName :: Text,
    trRate :: Double, -- Rate in percent (0-100)
    trFlags :: Int
  }
  deriving (Show, Eq)

-- | GoodsTax - Tax group for goods (corresponds to TaxGroup)
data GoodsTax = GoodsTax
  { gtId :: Int64,
    gtCode :: Text,
    gtName :: Text,
    gtTaxRate :: Double
  }
  deriving (Show, Eq)

-- ============================================================================
-- TAX CALCULATION FUNCTIONS
-- ============================================================================

roundTo :: Int -> Double -> Double
roundTo prec x = fromInteger (round (x * (10 ^ prec))) / (10 ^ prec)

-- | Calculate VAT amount
-- Invariant: calcVAT amount rate >= 0
-- Invariant: calcVAT amount rate <= amount (when rate <= 100)
calcVAT :: Double -> Double -> Double
calcVAT amount rate
  | amount < 0 || rate < 0 = 0
  | rate > 100 = 0 -- Invalid rate
  | otherwise = roundTo 2 (amount * rate / 100)

-- | Extract VAT from inclusive price
calcVATFromInclusive :: Double -> Double -> Double
calcVATFromInclusive amount rate
  | amount < 0 || rate < 0 = 0
  | rate > 100 = 0
  | otherwise = roundTo 2 (amount * rate / (100 + rate))

-- | Calculate price without VAT from inclusive price
calcPriceWithoutVAT :: Double -> Double -> Double
calcPriceWithoutVAT inclusive rate
  | inclusive < 0 || rate < 0 = 0
  | otherwise = roundTo 2 (inclusive * 100 / (100 + rate))

-- | Calculate price with VAT
calcTaxInclusive :: Double -> Double -> Double
calcTaxInclusive price rate
  | price < 0 || rate < 0 = 0
  | otherwise = roundTo 2 (price * (1 + rate / 100))

-- | Extract VAT from inclusive price (alias)
extractVAT :: Double -> Double -> Double
extractVAT = calcVAT

-- | Validate tax rate
validateTaxRate :: TaxRate -> Bool
validateTaxRate tr = trRate tr >= 0 && trRate tr <= 100

-- | Validate tax entry - all values must be non-negative
validateTaxEntry :: TaxEntry -> Bool
validateTaxEntry e = teVAT e >= 0 && teExcise e >= 0 && teSalesTax e >= 0

-- ============================================================================
-- TAX VECTOR CALCULATIONS (from C++ GTaxVect)
-- ============================================================================

-- | Calculate complete tax vector from amounts and rates
calcTaxVector :: Double -> Double -> (Double, Double, Double, Double) -> TaxVector
calcTaxVector amount qty (vatRate, exciseRate, salesTaxRate, propRate) =
  let vat = calcVAT amount vatRate
      excise = calcVAT amount exciseRate -- Could be absolute or per-unit
      stax = calcVAT amount salesTaxRate
      prop = calcVAT amount propRate
   in TaxVector
        { tvAmount = amount,
          tvQtty = qty,
          tvRates = (vatRate, exciseRate, salesTaxRate, propRate),
          tvValues = (vat, excise, stax, prop),
          tvAbsVect = 0,
          tvUnionVect = 0,
          tvRoundPrec = 2
        }

-- | Get total tax from tax vector
taxVectorTotal :: TaxVector -> Double
taxVectorTotal tv =
  let (v, e, s, p) = tvValues tv
   in v + e + s + p

-- | Get net amount from tax vector
taxVectorNet :: TaxVector -> Double
taxVectorNet tv = tvAmount tv

-- | Get gross amount (net + taxes)
taxVectorGross :: TaxVector -> Double
taxVectorGross tv = tvAmount tv + taxVectorTotal tv

-- | Validate tax vector invariants
validateTaxVector :: TaxVector -> Bool
validateTaxVector tv =
  let totals = taxVectorTotal tv
   in tvAmount tv >= 0 && totals >= 0

-- ============================================================================
-- EXCISE CALCULATIONS
-- ============================================================================

-- | Calculate excise tax
-- C++: GTAXF_ABSEXCISE flag determines if absolute or ad valorem
calcExcise :: Double -> Double -> Bool -> Double
calcExcise amount rate isAbsolute
  | isAbsolute = rate -- Absolute amount
  | otherwise = calcVAT amount rate -- Ad valorem

-- | Calculate unit excise (per quantity)
calcUnitExcise :: Double -> Double -> Double
calcUnitExcise unitRate qty = unitRate * qty

-- ============================================================================
-- QUICKCHECK PROPERTIES
-- ============================================================================

prop_vat_nonnegative :: Double -> Double -> Property
prop_vat_nonnegative amount rate =
  let vat = calcVAT amount rate
   in property (vat >= 0)

prop_vat_inclusive :: Double -> Double -> Property
prop_vat_inclusive amount rate =
  let vat = calcVAT amount rate
      withVat = amount + vat
   in property (abs (calcTaxInclusive withVat rate - vat) < 0.01)

prop_tax_rate_bounds :: TaxEntry -> Property
prop_tax_rate_bounds entry =
  property (validateTaxEntry entry)

-- | Property: VAT always less than or equal to original amount
prop_vat_bounded :: Double -> Double -> Property
prop_vat_bounded amount rate =
  let vat = calcVAT amount rate
   in property (vat <= amount)

-- | Property: Round-trip calculation
prop_vat_roundtrip :: Double -> Double -> Property
prop_vat_roundtrip price rate =
  let withVat = calcTaxInclusive price rate
      withoutVat = calcPriceWithoutVAT withVat rate
   in property (abs (withoutVat - price) < 0.01)
