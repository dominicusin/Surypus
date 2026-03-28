{-# LANGUAGE OverloadedStrings #-}
module Domain.BillSpec where

import Test.Hspec
import Domain.Bill

spec :: Spec
spec = do
  describe "Bill" $ do
    it "creates bill with required fields" $ do
      let b = Bill
            { billId = Nothing
            , billCode = Just "001"
            , billOpId = 1
            , billDate = read "2024-01-01"
            , billPersonId = Nothing
            , billLocationId = Nothing
            , billAmount = 1000
            , billVat = 200
            , billDiscount = 0
            , billStatus = 0
            , billCurrency = Nothing
            , billCreatedBy = Nothing
            , billNotes = Nothing
            , billLines = []
            }
      billCode b `shouldBe` Just "001"
