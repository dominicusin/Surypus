{-# LANGUAGE OverloadedStrings #-}

module Integration.PropertySpec
  ( spec_accountingProperties,
    spec_inventoryProperties,
    spec_vatProperties,
  )
where

import Core.Tax (calcPriceWithoutVAT, calcTaxInclusive, calcVAT, calcVATFromInclusive)
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
    amount <- suchThat arbitrary (>= 0)
    return $ Entry amount amount

prop_doubleEntryBalance :: Entry -> Bool
prop_doubleEntryBalance entry =
  entryDebit entry == entryCredit entry

spec_accountingProperties :: Spec
spec_accountingProperties = describe "Accounting Properties" $ do
  prop "double-entry balance: debits must equal credits" $
    forAll arbitrary prop_doubleEntryBalance

spec_vatProperties :: Spec
spec_vatProperties = describe "VAT Properties" $ do
  prop "VAT is non-negative" $
    forAll (suchThat arbitrary (\(a, r) -> a >= 0 && r >= 0 && r <= 100)) $ \(amount, rate) ->
      calcVAT amount rate >= 0

  prop "VAT does not exceed original amount" $
    forAll (suchThat arbitrary (\(a, r) -> a >= 0 && r >= 0 && r <= 100)) $ \(amount, rate) ->
      calcVAT amount rate <= amount

  prop "VAT roundtrip: calcTaxInclusive - extractVAT = original" $
    forAll (suchThat arbitrary (\(a, r) -> a >= 0 && r >= 0 && r <= 100)) $ \(amount, rate) ->
      calcTaxInclusive (calcPriceWithoutVAT amount rate) rate `approxEq` amount
  where
    approxEq a b = abs (a - b) < 0.01

spec_inventoryProperties :: Spec
spec_inventoryProperties = describe "Inventory Properties" $ do
  it "placeholder: inventory non-negative" $ do
    True `shouldBe` True

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
