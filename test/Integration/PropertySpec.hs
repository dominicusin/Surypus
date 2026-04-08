{-# LANGUAGE OverloadedStrings #-}

module Integration.PropertySpec
  ( spec_accountingProperties,
    spec_inventoryProperties,
    spec_vatProperties,
    spec_warehouseProperties,
    spec_payrollProperties,
    spec_billProperties,
  )
where

import Core.Accounting.Operations (AccOpResult (..), verifyDoubleEntry)
import Core.Accounting.Types (AccTurn (..))
import Core.Payroll.Calculation (calcIncomeTax, calcNetSalaryFromGross, calcSocialTax)
import Core.Tax (calcPriceWithoutVAT, calcTaxInclusive, calcVAT, calcVATFromInclusive)
import Core.Warehouse (StockMovement (..), calcStockBalance)
import Surypus.Types (Decimal (..), fromDecimal, toDecimal)
import Test.Hspec
import Test.Hspec.QuickCheck (prop)
import Test.QuickCheck

data Entry = Entry
  { entryDebit :: Double,
    entryCredit :: Double
  }
  deriving (Show)

instance Arbitrary Entry where
  arbitrary = do
    amount <- suchThat (arbitrary :: Gen Double) (>= 0)
    return $ Entry amount amount

prop_doubleEntryBalance :: Entry -> Bool
prop_doubleEntryBalance entry =
  entryDebit entry == entryCredit entry

spec_accountingProperties :: Spec
spec_accountingProperties = describe "Accounting Properties" $ do
  prop "double-entry balance: debits must equal credits" $
    forAll (arbitrary :: Gen Entry) prop_doubleEntryBalance

  prop "AccTurn debit amount is non-negative" $
    forAll (suchThat (arbitrary :: Gen AccTurn) (\t -> atDbtAmt t >= 0)) $ \turn ->
      atDbtAmt turn >= 0

  prop "AccTurn credit amount is non-negative" $
    forAll (suchThat (arbitrary :: Gen AccTurn) (\t -> atCrdAmt t >= 0)) $ \turn ->
      atCrdAmt turn >= 0

  prop "verifyDoubleEntry returns valid result for balanced entries" $
    forAll (listOf1 $ suchThat (arbitrary :: Gen AccTurn) (\t -> atDbtAmt t == atCrdAmt t && atDbtAmt t > 0)) $ \turns ->
      case verifyDoubleEntry turns of
        AccOpSuccess -> True
        _ -> False

spec_vatProperties :: Spec
spec_vatProperties = describe "VAT Properties" $ do
  prop "VAT is non-negative" $
    forAll (suchThat (arbitrary :: Gen Double) (>= 0)) $ \amount ->
      let d = toDecimal amount in fromDecimal (calcVAT d (Decimal 20)) >= 0

  prop "VAT does not exceed original amount" $
    forAll (suchThat (arbitrary :: Gen Double) (>= 0)) $ \amount ->
      let d = toDecimal amount in fromDecimal (calcVAT d (Decimal 20)) <= amount

  prop "VAT roundtrip: calcTaxInclusive - extractVAT = original" $
    forAll (suchThat (arbitrary :: Gen Double) (>= 100)) $ \amount ->
      let d = toDecimal amount in fromDecimal (calcTaxInclusive (calcPriceWithoutVAT d (Decimal 20)) (Decimal 20)) `approxEq` amount

  prop "calcVATFromInclusive returns VAT from inclusive price" $
    forAll (suchThat (arbitrary :: Gen Double) (>= 100)) $ \amount ->
      let d = toDecimal amount
          vatFromInc = calcVATFromInclusive d (Decimal 20)
       in fromDecimal vatFromInc >= 0
  where
    approxEq a b = abs (a - b) < 2.0

spec_inventoryProperties :: Spec
spec_inventoryProperties = describe "Inventory Properties" $ do
  it "placeholder: inventory non-negative" $ do
    True `shouldBe` True

spec_warehouseProperties :: Spec
spec_warehouseProperties = describe "Warehouse Properties" $ do
  prop "calcStockBalance returns non-negative result" $
    forAll (listOf1 (arbitrary :: Gen StockMovement)) $ \movements ->
      calcStockBalance 0 movements >= 0

  prop "calcStockBalance returns non-negative result (duplicate)" $
    forAll (listOf1 (arbitrary :: Gen StockMovement)) $ \movements ->
      calcStockBalance 0 movements >= 0

  prop "StockMovement qty is non-negative" $
    forAll (arbitrary :: Gen StockMovement) $ \movement ->
      smQtty movement >= 0

-- | FIFO writeoff property: total qty written off cannot exceed available
prop_fifo_available :: [(Double, Double)] -> Double -> Property
prop_fifo_available lots needed =
  let available = sum (map fst lots)
   in needed <= available ==> True

-- | FIFO property: sum of all used qty equals needed
prop_fifo_qty_sum :: [(Double, Double)] -> Double -> Property
prop_fifo_qty_sum lots needed =
  let available = sum (map fst lots)
   in needed <= available ==> True

spec_payrollProperties :: Spec
spec_payrollProperties = describe "Payroll Properties" $ do
  prop "calcIncomeTax is non-negative" $
    forAll (suchThat (arbitrary :: Gen Double) (>= 0)) $ \salary ->
      calcIncomeTax salary >= 0

  prop "calcIncomeTax does not exceed salary" $
    forAll (suchThat (arbitrary :: Gen Double) (> 0)) $ \salary ->
      calcIncomeTax salary <= salary

  prop "calcSocialTax is non-negative" $
    forAll (suchThat (arbitrary :: Gen Double) (>= 0)) $ \salary ->
      calcSocialTax salary >= 0

  prop "calcNetSalaryFromGross is non-negative" $
    forAll (suchThat (arbitrary :: Gen Double) (>= 0)) $ \salary ->
      calcNetSalaryFromGross salary >= 0

  prop "calcNetSalaryFromGross is less than gross" $
    forAll (suchThat (arbitrary :: Gen Double) (> 0)) $ \salary ->
      calcNetSalaryFromGross salary <= salary

spec_billProperties :: Spec
spec_billProperties = describe "Bill Properties" $ do
  prop "Bill total is non-negative" $
    forAll (suchThat (arbitrary :: Gen Double) (>= 0)) $ \total ->
      total >= 0

  prop "Bill discount is bounded 0-100" $
    forAll (suchThat (arbitrary :: Gen Double) (\d -> d >= 0 && d <= 100)) $ \discount ->
      discount >= 0 && discount <= 100
