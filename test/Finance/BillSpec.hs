{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE LambdaCase #-}

module Finance.BillSpec (spec) where

import Test.Hspec
import Data.Time.Calendar (fromGregorian)
import Finance.Bill

spec :: Spec
spec = do
  describe "Finance.Bill" $ do
    let testDate = fromGregorian 2024 1 15
        line1 = BillLine "Widget A" 2 50 20
        line2 = BillLine "Widget B" 1 100 10
        testBill = createBill "BILL-001" testDate "Customer X" [line1, line2]

    it "creates a draft bill" $ do
      billStatus testBill `shouldBe` BillDraft
      billNumber testBill `shouldBe` "BILL-001"
      length (billLines testBill) `shouldBe` 2

    it "calculates total with tax" $ do
      let (total, tax) = calculateBillTotal [line1, line2]
      -- line1: 2*50 + 20% = 100 + 20 = 120
      -- line2: 1*100 + 10% = 100 + 10 = 110
      total `shouldBe` 230.0
      tax `shouldBe` 30.0

    it "validates bill with lines" $ do
      validateBill testBill `shouldBe` Right ()

    it "rejects empty bill" $ do
      let emptyBill = createBill "EMPTY" testDate "Nobody" []
      validateBill emptyBill `shouldSatisfy` \case
        Left _ -> True
        Right _ -> False

    it "posts a valid bill" $ do
      postBill testBill `shouldBe` BillPostedOk

    it "rejects posting already posted bill" $ do
      let postedBill = testBill { billStatus = BillPosted }
      postBill postedBill `shouldBe` BillAlreadyPosted
