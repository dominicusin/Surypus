{-# LANGUAGE OverloadedStrings #-}
module Domain.BillSpec where

import Test.Hspec
import Test.QuickCheck (Positive(..), NonNegative(..), property)
import Domain.Bill
import Core.Refined (clampNonNeg)
import Core.Tax (calcVAT)
import Data.Either (isLeft, isRight)
import Data.Time (fromGregorian)

spec :: Spec
spec = do
  describe "BillLine" $ do
    it "computes amount with VAT" $ do
      let line = BillLine
            { billLineId = Nothing
            , billLineGoodsId = 1
            , billLinePrice = 100
            , billLineQuantity = 2
            , billLineDiscount = 0
            , billLineVatRate = 20
            , billLineTax = 40
            , billLineAmount = 240
            }
      calcBillLineAmount line `shouldBe` 240
      validateBillLine line `shouldBe` Right line

    it "rejects inconsistent tax" $ do
      let line = BillLine
            { billLineId = Nothing
            , billLineGoodsId = 1
            , billLinePrice = 100
            , billLineQuantity = 1
            , billLineDiscount = 0
            , billLineVatRate = 0
            , billLineTax = 50
            , billLineAmount = 150
            }
      validateBillLine line `shouldSatisfy` isLeft

    it "calculates totals consistently (QuickCheck)" $ property $
      \(Positive qty) (NonNegative price) (NonNegative discount) (NonNegative vatRate) -> do
        let vatRateClamped = min 100 vatRate
            net = clampNonNeg (qty * price - discount)
            tax = calcVAT net vatRateClamped
            total = clampNonNeg (net + tax)
            line = BillLine Nothing 1 price qty discount vatRateClamped tax total
        calcBillLineAmount line `shouldBe` total
        calcLineTaxExpected line `shouldBe` tax

  describe "Bill" $ do
    it "sums totals" $ do
      let line = BillLine Nothing 1 40 3 0 10 12 132
      calcBillTotal [line, line] `shouldBe` 264

    it "validates positive bill" $ do
      let bill = Bill
            { billId = Nothing
            , billCode = Just "0001"
            , billOpId = 1
            , billDate = fromGregorian 2025 12 1
            , billPersonId = Nothing
            , billLocationId = Nothing
            , billAmount = 120
            , billVat = 20
            , billDiscount = 0
            , billStatus = 0
            , billCurrency = Nothing
            , billCreatedBy = Nothing
            , billNotes = Nothing
            , billLines = [BillLine Nothing 1 50 2 0 10 10 110]
            }
      validateBill bill `shouldSatisfy` isRight
