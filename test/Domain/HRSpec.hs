{-# LANGUAGE OverloadedStrings #-}
module Domain.HRSpec where

import Data.Either (isLeft, isRight)
import Data.Time (addDays, fromGregorian)
import Test.Hspec
import Test.QuickCheck
import Domain.HR

spec :: Spec
spec = do
  describe "SalaryRecord" $ do
    it "validates non-negative amounts" $ do
      let record = SalaryRecord Nothing 1 1 (fromGregorian 2026 1 1) (fromGregorian 2026 1 31) (-100) Nothing Nothing Nothing
      validateSalaryRecord record `shouldSatisfy` isLeft

    it "validates period" $ do
      let record = SalaryRecord Nothing 1 1 (fromGregorian 2026 2 1) (fromGregorian 2026 1 31) 100 Nothing Nothing Nothing
      validateSalaryRecord record `shouldSatisfy` isLeft

  describe "SalarySummary" $ do
    it "clamps negative totals" $ do
      let summary = mkSalarySummary 1 "Ivan" "Developer" (-1000)
      ssTotal summary `shouldEqual` 0

  describe "SalaryChargeInput" $ do
    it "rejects empty names" $ do
      let input = SalaryChargeInput "" Nothing 0
      validateSalaryChargeInput input `shouldSatisfy` isLeft

    it "rejects negative flags" $ do
      let input = SalaryChargeInput "Bonus" Nothing (-1)
      validateSalaryChargeInput input `shouldSatisfy` isLeft

    it "normalizes names and codes" $ do
      let input = SalaryChargeInput "  Night shift  " (Just " ns ") 0
      case validateSalaryChargeInput input of
        Left err -> expectationFailure ("expected success, got " <> err)
        Right normalized -> do
          let charge = mkSalaryCharge normalized
          scName charge `shouldBe` "Night shift"
          scCode charge `shouldBe` Just "NS"

  describe "SalaryRecord per-day calculation" $ do
    it "is consistent with total amount" $ property $
      \(Positive amt) (Positive days) -> do
        let start = fromGregorian 2026 1 1
            end = addDays (fromIntegral (days - 1)) start
            record = SalaryRecord Nothing 1 1 start end amt Nothing Nothing Nothing
            perDay = calcSalaryPerDay record
            totalDays = fromIntegral days
            reconstructed = perDay * totalDays
        abs (reconstructed - amt) `shouldSatisfy` (< 1e-6)
        perDay `shouldSatisfy` (>= 0)
