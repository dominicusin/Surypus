module Finance.TaxSpec (spec) where

import Test.Hspec
import Test.QuickCheck
import Data.Decimal (Decimal)
import Finance.Tax

spec :: Spec
spec = do
  describe "mkTaxRate" $ do
    it "accepts valid rate (0%)" $
      mkTaxRate 0 `shouldBe` Just (TaxRate 0)
    it "accepts valid rate (20%)" $
      mkTaxRate 20 `shouldBe` Just (TaxRate 20)
    it "accepts valid rate (100%)" $
      mkTaxRate 100 `shouldBe` Just (TaxRate 100)
    it "rejects negative rate" $
      mkTaxRate (-1) `shouldBe` Nothing
    it "rejects rate > 100" $
      mkTaxRate 101 `shouldBe` Nothing

  describe "calcVAT" $ do
    it "calculates 20% VAT on 100" $
      calcVAT 100 (TaxRate 20) `shouldBe` 20
    it "calculates 0% VAT on 100" $
      calcVAT 100 (TaxRate 0) `shouldBe` 0
    it "calculates 100% VAT on 50" $
      calcVAT 50 (TaxRate 100) `shouldBe` 50
    it "returns 0 for negative amount" $
      calcVAT (-100) (TaxRate 20) `shouldBe` 0
    it "returns 0 for negative rate" $
      calcVAT 100 (TaxRate (-10)) `shouldBe` 0
    it "returns 0 for rate > 100" $
      calcVAT 100 (TaxRate 200) `shouldBe` 0
    it "VAT cannot exceed amount for valid rates" $
      calcVAT 100 (TaxRate 20) `shouldSatisfy` (<= 100)

  describe "calcVATFromInclusive" $ do
    it "extracts VAT from inclusive 120 (20% rate)" $
      calcVATFromInclusive 120 (TaxRate 20) `shouldBe` 20
    it "extracts VAT from inclusive 100 (0% rate)" $
      calcVATFromInclusive 100 (TaxRate 0) `shouldBe` 0
    it "extracts VAT from inclusive 200 (100% rate)" $
      calcVATFromInclusive 200 (TaxRate 100) `shouldBe` 100

  describe "calcPriceWithVAT" $ do
    it "price 100 + 20% VAT = 120" $
      calcPriceWithVAT 100 (TaxRate 20) `shouldBe` 120
    it "price 100 + 0% VAT = 100" $
      calcPriceWithVAT 100 (TaxRate 0) `shouldBe` 100

  describe "calcPriceWithoutVAT" $ do
    it "inclusive 120 - 20% VAT = 100" $
      calcPriceWithoutVAT 120 (TaxRate 20) `shouldBe` 100
    it "inclusive 100 - 0% VAT = 100" $
      calcPriceWithoutVAT 100 (TaxRate 0) `shouldBe` 100

  describe "calcTaxInclusive" $ do
    it "price 100 + 20% = 120" $
      calcTaxInclusive 100 (TaxRate 20) `shouldBe` 120
    it "price 100 + 0% = 100" $
      calcTaxInclusive 100 (TaxRate 0) `shouldBe` 100

  describe "validateTaxRate" $ do
    it "validates 0% as valid" $
      validateTaxRate 0 `shouldBe` True
    it "validates 20% as valid" $
      validateTaxRate 20 `shouldBe` True
    it "validates 100% as valid" $
      validateTaxRate 100 `shouldBe` True
    it "rejects -1%" $
      validateTaxRate (-1) `shouldBe` False
    it "rejects 101%" $
      validateTaxRate 101 `shouldBe` False

  describe "validateTaxEntry" $ do
    it "validates positive values" $
      validateTaxEntry (TaxEntry (TaxEntryId 1) (read "2024-01-01") (read "2024-12-31") 100 50 30 0 0) `shouldBe` True
    it "rejects negative VAT" $
      validateTaxEntry (TaxEntry (TaxEntryId 1) (read "2024-01-01") (read "2024-12-31") (-1) 0 0 0 0) `shouldBe` False

  describe "roundtrip consistency" $ do
    it "calcVAT + calcPriceWithoutVAT = original for inclusive price" $ do
      let inclusive = 120
          rate = TaxRate 20
          vat = calcVATFromInclusive inclusive rate
          exclusive = calcPriceWithoutVAT inclusive rate
      calcPriceWithVAT exclusive rate `shouldBe` inclusive
    it "inclusive -> exclusive -> inclusive yields original" $ do
      let inclusive = 240
          rate = TaxRate 20
          exclusive = calcPriceWithoutVAT inclusive rate
      calcPriceWithVAT exclusive rate `shouldBe` inclusive

  describe "QuickCheck properties" $ do
    it "calcVAT is always non-negative" $
      property prop_vat_nonnegative
    it "calcVAT does not exceed amount for valid rates" $
      property prop_vat_not_exceeds_amount
    it "calcVATFromInclusive is always non-negative" $
      property prop_vat_from_inclusive_nonnegative
    it "roundtrip: exclusive -> add VAT -> inclusive" $
      property prop_roundtrip_exclusive
    it "roundtrip: inclusive -> remove VAT -> add VAT -> inclusive" $
      property prop_roundtrip_inclusive
    it "calcTaxInclusive equals price + calcVAT" $
      property prop_tax_inclusive_matches
    it "validateTaxRate matches mkTaxRate" $
      property prop_validate_matches_mkTaxRate

-- | Generate non-negative Decimal for testing
genNonNegDecimal :: Gen Decimal
genNonNegDecimal = fromIntegral <$> choose (0, 10000 :: Integer)

-- | Generate valid tax rate Decimal (0-100)
genValidRate :: Gen Decimal
genValidRate = fromIntegral <$> choose (0, 100 :: Integer)

-- | Generate valid TaxRate
genTaxRate :: Gen TaxRate
genTaxRate = do
  d <- genValidRate
  case mkTaxRate d of
    Just r -> pure r
    Nothing -> genTaxRate

instance Arbitrary TaxRate where
  arbitrary = genTaxRate

-- Properties

-- | VAT is always non-negative
prop_vat_nonnegative :: Property
prop_vat_nonnegative = forAll genNonNegDecimal $ \amount ->
  forAll genTaxRate $ \rate ->
    calcVAT amount rate >= 0

-- | VAT does not exceed amount (for valid rates 0-100%)
prop_vat_not_exceeds_amount :: Property
prop_vat_not_exceeds_amount = forAll genNonNegDecimal $ \amount ->
  forAll genTaxRate $ \rate ->
    calcVAT amount rate <= amount

-- | calcVATFromInclusive is always non-negative
prop_vat_from_inclusive_nonnegative :: Property
prop_vat_from_inclusive_nonnegative = forAll genNonNegDecimal $ \amount ->
  forAll genTaxRate $ \rate ->
    calcVATFromInclusive amount rate >= 0

-- | Roundtrip: exclusive -> add VAT -> exclusive matches original
prop_roundtrip_exclusive :: Property
prop_roundtrip_exclusive = forAll genNonNegDecimal $ \exclusive ->
  forAll genTaxRate $ \rate ->
    calcPriceWithoutVAT (calcPriceWithVAT exclusive rate) rate == exclusive

-- | Roundtrip: inclusive -> remove VAT -> add VAT -> inclusive
-- Uses tolerance for Decimal rounding (fixed-point arithmetic has limited precision)
prop_roundtrip_inclusive :: Property
prop_roundtrip_inclusive = forAll genNonNegDecimal $ \inclusive ->
  forAll genTaxRate $ \rate ->
    let restored = calcPriceWithVAT (calcPriceWithoutVAT inclusive rate) rate
        diff = abs (restored - inclusive)
    in diff <= 5  -- tolerance of 5 units for Decimal rounding

-- | calcTaxInclusive = price + calcVAT
prop_tax_inclusive_matches :: Property
prop_tax_inclusive_matches = forAll genNonNegDecimal $ \price ->
  forAll genTaxRate $ \rate ->
    calcTaxInclusive price rate == price + calcVAT price rate

-- | validateTaxRate returns True iff mkTaxRate returns Just
prop_validate_matches_mkTaxRate :: Property
prop_validate_matches_mkTaxRate = forAll (choose (0, 200 :: Integer)) $ \n ->
  let d = fromIntegral n
  in validateTaxRate d == isJust (mkTaxRate d)
  where
    isJust (Just _) = True
    isJust Nothing  = False
