-- | Tax Calculation Module - GTaxVect equivalent from  C<>
-- Supports: VAT, Excise, Sales Tax with forward/backward calculation
--
-- = Formal Verification (LiquidHaskell)
--
-- >>> :{
--  {-@ type NonNeg = {v:Decimal | v >= 0} @-}
--  {-@ type TaxRate = {v:Decimal | v >= 0 && v <= 100} @-}
-- :}
--
-- >>> :{
--  {-@ calcVAT :: amount:NonNeg -> rate:TaxRate -> NonNeg @-}
--  {-@ calcVATFromInclusive :: amount:NonNeg -> rate:TaxRate -> NonNeg @-}
-- :}
module Core.Tax
  ( calcVAT,
    calcVATFromInclusive,
    calcPriceWithoutVAT,
    calcTaxInclusive,
    extractVAT,
    validateTaxRate,
    validateTaxEntry,
    calcTaxVector,
    taxVectorTotal,
    taxVectorNet,
    taxVectorGross,
    validateTaxVector,
    calcExcise,
    calcUnitExcise,
    TaxVector (..),
    TaxEntry (..),
    TaxRate (..),
    TaxFlags (..),
    TaxCalcType (..),
    GoodsTax (..),
    defaultTaxFlags,
    defaultTaxVector,
    prop_vat_nonnegative,
    prop_vat_bounded,
    prop_vat_roundtrip,
    prop_tax_vector_total_nonneg,
    prop_tax_vector_gross_ge_net,
    prop_tax_vector_valid,
  )
where

import Data.Int (Int64)
import Data.Text (Text)
import Surypus.Types (Decimal (..))
import Test.QuickCheck

-- ============================================================================
-- TAX TYPES
-- ============================================================================

-- | Tax calculation types
data TaxCalcType = TaxCalcTypeVAT | TaxCalcTypeExcise | TaxCalcTypeSalesTax | TaxCalcTypeProperty
  deriving (Show, Eq, Enum)

-- | Tax flags from C<> GTAXF_*
data TaxFlags = TaxFlags
  { tfAbsolute :: Bool, -- GTAXF_ABSVAT
    tfUnion :: Bool, -- GTAXF_UNION
    tfIncluded :: Bool, -- GTAXF_INCLUDED
    tfNoCalculable :: Bool -- GTAXF_NOCALC
  }
  deriving (Show, Eq)

defaultTaxFlags :: TaxFlags
defaultTaxFlags = TaxFlags False False False False

-- | Tax entry - corresponds to PPGoodsTaxEntry in C<>
-- Invariant: All tax values >= 0
data TaxEntry = TaxEntry
  { teTaxGrpId :: Int64, -- Tax group ID
    tePeriodStart :: Int, -- Period start (days since epoch)
    tePeriodEnd :: Int, -- Period end
    teOpId :: Int64, -- Operation ID
    teVAT :: Decimal, -- VAT rate (0-100)
    teExcise :: Decimal, -- Excise rate
    teSalesTax :: Decimal, -- Sales tax rate
    teFlags :: TaxFlags,
    teOrder :: Int, -- Order of application
    teUnionVect :: Int -- Union vector
  }
  deriving (Show, Eq)

-- | Tax vector - corresponds to GTaxVect in C<>
data TaxVector = TaxVector
  { tvAmount :: Decimal, -- Net amount
    tvQtty :: Decimal, -- Quantity
    tvRates :: (Decimal, Decimal, Decimal, Decimal), -- (VAT, Excise, SalesTax, Property)
    tvValues :: (Decimal, Decimal, Decimal, Decimal), -- Calculated values
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
    trRate :: Decimal, -- Rate in percent (0-100)
    trFlags :: Int
  }
  deriving (Show, Eq)

-- | GoodsTax - Tax group for goods (corresponds to TaxGroup)
data GoodsTax = GoodsTax
  { gtId :: Int64,
    gtCode :: Text,
    gtName :: Text,
    gtTaxRate :: Decimal
  }
  deriving (Show, Eq)

-- ============================================================================
-- TAX CALCULATION FUNCTIONS
-- ============================================================================

roundTo :: Int -> Decimal -> Decimal
roundTo _ (Decimal x) =
  let whole = div (x + 50) 100
   in Decimal (whole * 100)

-- | Calculate VAT amount
-- Invariant: calcVAT amount rate >= 0
-- Invariant: calcVAT amount rate <= amount (when rate <= 100)
calcVAT :: Decimal -> Decimal -> Decimal
calcVAT amount rate
  | amount < 0 || rate < 0 = 0
  | rate > 100 = 0 -- Invalid rate
  | otherwise = roundTo 2 (amount * rate / 100)

-- | Extract VAT from inclusive price
calcVATFromInclusive :: Decimal -> Decimal -> Decimal
calcVATFromInclusive amount rate
  | amount < 0 || rate < 0 = 0
  | rate > 100 = 0
  | otherwise =
      -- VAT = inclusive * rate / (1 + rate) where rate is a decimal (0.20 for 20%)
      -- We need to perform the division manually to avoid the Fractional instance's multiplication by 10000
      let divisor = unDecimal (1 :: Decimal) + unDecimal rate -- 100 + 20 = 120
       in roundTo 2 (Decimal (div (unDecimal amount * unDecimal rate) divisor))

-- | Calculate price without VAT from inclusive price
calcPriceWithoutVAT :: Decimal -> Decimal -> Decimal
calcPriceWithoutVAT inclusive rate
  | inclusive < 0 || rate < 0 = 0
  | otherwise =
      -- inclusive / (1 + rate) where rate is a decimal (0.20 for 20%)
      -- We need to perform the division manually to avoid the Fractional instance's multiplication by 10000
      let divisor = unDecimal (1 :: Decimal) + unDecimal rate -- 100 + 20 = 120
       in roundTo 2 (Decimal (div (unDecimal inclusive * 100) divisor))

-- | Calculate price with VAT
calcTaxInclusive :: Decimal -> Decimal -> Decimal
calcTaxInclusive price rate
  | price < 0 || rate < 0 = 0
  | otherwise =
      -- price * (1 + rate) where rate is a decimal (0.20 for 20%)
      let multiplier = unDecimal (1 :: Decimal) + unDecimal rate -- 100 + 20 = 120
       in roundTo 2 (Decimal (div (unDecimal price * multiplier) 100))

-- | Extract VAT from inclusive price (alias)
extractVAT :: Decimal -> Decimal -> Decimal
extractVAT = calcVATFromInclusive

-- | Validate tax rate
validateTaxRate :: TaxRate -> Bool
validateTaxRate tr = trRate tr >= 0 && trRate tr <= 100

-- | Validate tax entry - all values must be non-negative
validateTaxEntry :: TaxEntry -> Bool
validateTaxEntry e = teVAT e >= 0 && teExcise e >= 0 && teSalesTax e >= 0

-- ============================================================================
-- TAX VECTOR CALCULATIONS (from C<> GTaxVect)
-- ============================================================================

-- | Calculate complete tax vector from amounts and rates
calcTaxVector :: Decimal -> Decimal -> (Decimal, Decimal, Decimal, Decimal) -> TaxVector
calcTaxVector amount qty (vatRate, exciseRate, salesTaxRate, propRate) =
  -- Convert rates from hundredths of a percent to percentages
  let vat = calcVAT amount (Decimal (div (unDecimal vatRate) 100))
      excise = calcVAT amount (Decimal (div (unDecimal exciseRate) 100)) -- Could be absolute or per-unit
      stax = calcVAT amount (Decimal (div (unDecimal salesTaxRate) 100))
      prop = calcVAT amount (Decimal (div (unDecimal propRate) 100))
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
taxVectorTotal :: TaxVector -> Decimal
taxVectorTotal tv =
  let (v, e, s, p) = tvValues tv
   in v + e + s + p

-- | Get net amount from tax vector
taxVectorNet :: TaxVector -> Decimal
taxVectorNet = tvAmount

-- | Get gross amount (net + taxes)
taxVectorGross :: TaxVector -> Decimal
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
-- C<>: GTAXF_ABSEXCISE flag determines if absolute or ad valorem
calcExcise :: Decimal -> Decimal -> Bool -> Decimal
calcExcise amount rate isAbsolute
  | isAbsolute = rate -- Absolute amount
  | otherwise =
      -- Ad valorem: rate is in hundredths of a percent (e.g., Decimal 1000 for 10%)
      -- Convert to percentage: Decimal 1000 -> Decimal 10
      let ratePercent = Decimal (div (unDecimal rate) 100)
       in calcVAT amount ratePercent

-- | Calculate unit excise (per quantity)
calcUnitExcise :: Decimal -> Decimal -> Decimal
calcUnitExcise unitRate qty =
  -- Use the standard Decimal multiplication
  unitRate * qty

-- ============================================================================
-- QUICKCHECK PROPERTIES
-- ============================================================================

-- | Property: VAT is always non-negative
prop_vat_nonnegative :: Decimal -> Decimal -> Property
prop_vat_nonnegative amount rate =
  let vat = calcVAT amount rate
   in property (vat >= 0)

-- | Property: VAT is always less than or equal to original amount (when rate <= 100)
prop_vat_bounded :: Decimal -> Decimal -> Property
prop_vat_bounded amount rate =
  let vat = calcVAT amount rate
   in property (rate <= 100 ==> vat <= amount)

-- | Property: Round-trip calculation
prop_vat_roundtrip :: Decimal -> Decimal -> Property
prop_vat_roundtrip price rate =
  let withVat = calcTaxInclusive price rate
      withoutVat = calcPriceWithoutVAT withVat rate
   in property (abs (withoutVat - price) < 0.01)

-- | Property: Tax vector total is non-negative
prop_tax_vector_total_nonneg :: TaxVector -> Property
prop_tax_vector_total_nonneg tv =
  property (taxVectorTotal tv >= 0)

-- | Property: Gross >= Net (taxes are added)
prop_tax_vector_gross_ge_net :: TaxVector -> Property
prop_tax_vector_gross_ge_net tv =
  property (taxVectorGross tv >= taxVectorNet tv)

-- | Property: Tax vector invariant
prop_tax_vector_valid :: TaxVector -> Property
prop_tax_vector_valid tv =
  property (validateTaxVector tv)
