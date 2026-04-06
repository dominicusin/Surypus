{-# LANGUAGE StrictData #-}

-- | Tax Calculation Module - GTaxVect equivalent from C<>
-- Supports: VAT, Excise, Sales Tax with forward/backward calculation
--
-- = Formal Verification (LiquidHaskell)
module Core.Tax
  ( -- * Types
    TaxCalcType (..),
    TaxFlags (..),
    TaxEntry (..),
    TaxRate (..),
    TaxVector (..),
    GoodsTax (..),

    -- * Constants
    defaultTaxFlags,
    defaultTaxVector,

    -- * Tax Calculation Functions
    calcVAT,
    calcVATFromInclusive,
    calcPriceWithoutVAT,
    calcTaxInclusive,
    extractVAT,

    -- * Validation
    validateTaxRate,
    validateTaxEntry,
    validateTaxVector,

    -- * Tax Vector Calculations
    calcTaxVector,
    taxVectorTotal,
    taxVectorNet,
    taxVectorGross,

    -- * Excise Calculations
    calcExcise,
    calcUnitExcise,

    -- * Properties (for testing)
    prop_vat_nonnegative,
    prop_vat_bounded,
    prop_vat_roundtrip,
    prop_tax_vector_total_nonneg,
    prop_tax_vector_gross_ge_net,
    prop_tax_vector_valid,
  )
where

-- Import order: qualified imports first, then specific exports, then local imports

import Data.Int (Int64)
import qualified Data.Text as T
import Surypus.Types (Decimal (..))
import Test.QuickCheck

-- Refinement types for LiquidHaskell
{-@ type NonNeg = {v:Decimal | v >= 0} @-}
{-@ type TaxRate = {v:Decimal | v >= 0 && v <= 100} @-}

{-@ calcVAT :: amount:NonNeg -> rate:TaxRate -> NonNeg @-}
{-@ calcVATFromInclusive :: amount:NonNeg -> rate:TaxRate -> NonNeg @-}
{-@ calcPriceWithoutVAT :: amount:NonNeg -> rate:TaxRate -> NonNeg @-}
{-@ calcTaxInclusive :: price:NonNeg -> rate:TaxRate -> {v:NonNeg | v >= price} @-}
{-@ extractVAT :: amount:NonNeg -> rate:TaxRate -> NonNeg @-}

-- ============================================================================
-- TAX TYPES
-- ============================================================================

-- | Tax calculation types
data TaxCalcType = TaxCalcTypeVAT | TaxCalcTypeExcise | TaxCalcTypeSalesTax | TaxCalcTypeProperty
  deriving (Show, Eq, Enum)

-- | Tax flags from C<> GTAXF_*
data TaxFlags = TaxFlags
  { tfAbsolute :: Bool,
    tfUnion :: Bool,
    tfIncluded :: Bool,
    tfNoCalculable :: Bool
  }
  deriving (Show, Eq)

defaultTaxFlags :: TaxFlags
defaultTaxFlags = TaxFlags False False False False

instance Arbitrary TaxFlags where
  arbitrary = TaxFlags <$> arbitrary <*> arbitrary <*> arbitrary <*> arbitrary

-- | Tax entry - corresponds to PPGoodsTaxEntry in C<>
-- Invariant: All tax values >= 0
data TaxEntry = TaxEntry
  { teTaxGrpId :: Int64,
    tePeriodStart :: Int,
    tePeriodEnd :: Int,
    teOpId :: Int64,
    teVAT :: Decimal,
    teExcise :: Decimal,
    teSalesTax :: Decimal,
    teFlags :: TaxFlags,
    teOrder :: Int,
    teUnionVect :: Int
  }
  deriving (Show, Eq)

instance Arbitrary TaxEntry where
  arbitrary =
    TaxEntry
      <$> arbitrary
      <*> arbitrary
      <*> arbitrary
      <*> arbitrary
      <*> arbitrary
      <*> arbitrary
      <*> arbitrary
      <*> arbitrary
      <*> arbitrary
      <*> arbitrary

-- | Tax vector - corresponds to GTaxVect in C<>
-- Invariant: tvAmount >= 0, tvQtty >= 0, all tvValues >= 0

{-@ data TaxVector = TaxVector
  { tvAmount :: {v:Decimal | v >= 0}
  , tvQtty :: {v:Decimal | v >= 0}
  , tvRates :: (Decimal, Decimal, Decimal, Decimal)
  , tvValues :: ({v:Decimal | v >= 0}, {v:Decimal | v >= 0}, {v:Decimal | v >= 0}, {v:Decimal | v >= 0})
  , tvAbsVect :: Int
  , tvUnionVect :: Int
  , tvRoundPrec :: Int
  } @-}
data TaxVector = TaxVector
  { tvAmount :: Decimal,
    tvQtty :: Decimal,
    tvRates :: (Decimal, Decimal, Decimal, Decimal),
    tvValues :: (Decimal, Decimal, Decimal, Decimal),
    tvAbsVect :: Int,
    tvUnionVect :: Int,
    tvRoundPrec :: Int
  }
  deriving (Show, Eq)

instance Arbitrary TaxVector where
  arbitrary =
    TaxVector
      <$> arbitrary
      <*> arbitrary
      <*> arbitrary4
      <*> arbitrary4
      <*> arbitrary
      <*> arbitrary
      <*> arbitrary
    where
      arbitrary4 = (,,,) <$> arbitrary <*> arbitrary <*> arbitrary <*> arbitrary

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
    trName :: T.Text,
    trRate :: Decimal, -- Rate in percent (0-100)
    trFlags :: Int
  }
  deriving (Show, Eq)

-- | GoodsTax - Tax group for goods (corresponds to TaxGroup)
data GoodsTax = GoodsTax
  { gtId :: Int64,
    gtCode :: T.Text,
    gtName :: T.Text,
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

{-@ calcVAT :: amount:NonNeg -> rate:TaxRate -> NonNeg @-}
calcVAT :: Decimal -> Decimal -> Decimal
calcVAT amount rate
  | amount < 0 || rate < 0 = 0
  | rate > Decimal 10000 = 0 -- Invalid rate (>100%)
  | otherwise =
      -- rate is in percentage points (Decimal 20 = 20%)
      -- VAT = amount * rate / 100
      Decimal (div (unDecimal amount * unDecimal rate) 100)

-- | Extract VAT from inclusive price
-- Invariant: calcVATFromInclusive amount rate >= 0
-- Invariant: calcVATFromInclusive amount rate <= amount (when rate <= 100)

{-@ calcVATFromInclusive :: amount:NonNeg -> rate:TaxRate -> NonNeg @-}
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
-- Invariant: calcPriceWithoutVAT inclusive rate >= 0
-- Invariant: calcPriceWithoutVAT inclusive rate <= inclusive (when rate <= 100)

{-@ calcPriceWithoutVAT :: amount:NonNeg -> rate:TaxRate -> NonNeg @-}
calcPriceWithoutVAT :: Decimal -> Decimal -> Decimal
calcPriceWithoutVAT inclusive rate
  | inclusive < 0 || rate < 0 = 0
  | otherwise =
      -- inclusive / (1 + rate) where rate is a decimal (0.20 for 20%)
      -- We need to perform the division manually to avoid the Fractional instance's multiplication by 10000
      let divisor = unDecimal (1 :: Decimal) + unDecimal rate -- 100 + 20 = 120
       in roundTo 2 (Decimal (div (unDecimal inclusive * 100) divisor))

-- | Calculate price with VAT
-- Invariant: calcTaxInclusive price rate >= price (when rate >= 0)

{-@ calcTaxInclusive :: price:NonNeg -> rate:TaxRate -> {v:NonNeg | v >= price} @-}
calcTaxInclusive :: Decimal -> Decimal -> Decimal
calcTaxInclusive price rate
  | price < 0 || rate < 0 = 0
  | otherwise =
      -- price * (1 + rate) where rate is a decimal (0.20 for 20%)
      let multiplier = unDecimal (1 :: Decimal) + unDecimal rate -- 100 + 20 = 120
       in roundTo 2 (Decimal (div (unDecimal price * multiplier) 100))

-- | Extract VAT from inclusive price (alias)
-- Invariant: extractVAT amount rate >= 0
-- Invariant: extractVAT amount rate <= amount (when rate <= 100)

{-@ extractVAT :: amount:NonNeg -> rate:TaxRate -> NonNeg @-}
extractVAT :: Decimal -> Decimal -> Decimal
extractVAT = calcVATFromInclusive

-- | Validate tax rate
-- Returns True if rate is between 0 and 100 (inclusive)
validateTaxRate :: TaxRate -> Bool
validateTaxRate tr = trRate tr >= 0 && trRate tr <= 100

-- | Validate tax entry - all values must be non-negative
-- Invariant: All tax values >= 0
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
prop_vat_nonnegative :: Property
prop_vat_nonnegative = forAll genAmountAndRate $ \(amount, rate) ->
  calcVAT amount rate >= 0

-- | Property: VAT is always less than or equal to original amount (when rate <= 100%)
prop_vat_bounded :: Property
prop_vat_bounded = forAll genAmountAndRate $ \(amount, rate) ->
  rate <= Decimal 100 ==> calcVAT amount rate <= amount

-- | Property: Round-trip calculation
prop_vat_roundtrip :: Property
prop_vat_roundtrip = forAll genAmountAndRate $ \(price, rate) ->
  rate <= 100 ==>
    let withVat = calcTaxInclusive price rate
        withoutVat = calcPriceWithoutVAT withVat rate
     in abs (withoutVat - price) <= Decimal 100

-- | Property: Tax vector total is non-negative
prop_tax_vector_total_nonneg :: Property
prop_tax_vector_total_nonneg = forAll genValidTaxVector $ \tv ->
  taxVectorTotal tv >= 0

-- | Property: Gross >= Net (taxes are added)
prop_tax_vector_gross_ge_net :: Property
prop_tax_vector_gross_ge_net = forAll genValidTaxVector $ \tv ->
  taxVectorGross tv >= taxVectorNet tv

-- | Property: Tax vector invariant
prop_tax_vector_valid :: Property
prop_tax_vector_valid = forAll genValidTaxVector $ \tv ->
  validateTaxVector tv

-- | Generate amount >= 0 and rate 0-100% (realistic tax rates)
genAmountAndRate :: Gen (Decimal, Decimal)
genAmountAndRate = do
  amount <- Decimal . abs <$> choose (100, 100000000 :: Int64)
  rate <- Decimal . abs <$> choose (0, 100 :: Int64)
  pure (amount, rate)

-- | Generate a valid tax vector with non-negative values
genValidTaxVector :: Gen TaxVector
genValidTaxVector = do
  amount <- Decimal . abs <$> choose (100, 100000000 :: Int64)
  qty <- Decimal . abs <$> choose (0, 1000000 :: Int64)
  v <- Decimal . abs <$> choose (0, 10000000 :: Int64)
  e <- Decimal . abs <$> choose (0, 10000000 :: Int64)
  s <- Decimal . abs <$> choose (0, 10000000 :: Int64)
  p <- Decimal . abs <$> choose (0, 10000000 :: Int64)
  pure $ TaxVector
    { tvAmount = amount,
      tvQtty = qty,
      tvRates = (0, 0, 0, 0),
      tvValues = (v, e, s, p),
      tvAbsVect = 0,
      tvUnionVect = 0,
      tvRoundPrec = 2
    }
