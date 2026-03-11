{-# LANGUAGE OverloadedStrings #-}
module Domain.PayrollSpec where

import Test.Hspec
import Data.Time (fromGregorian)
import Domain.Payroll
import Data.Either (isLeft, isRight)

spec :: Spec
spec = do
  describe "PayrollSnapshotRequest" $ do
    it "rejects inverted periods" $ do
      let req = PayrollSnapshotRequest (fromGregorian 2025 12 31) (fromGregorian 2025 1 1)
      validatePayrollSnapshotRequest req `shouldSatisfy` isLeft

    it "rejects ranges longer than one year" $ do
      let req = PayrollSnapshotRequest (fromGregorian 2024 1 1) (fromGregorian 2025 1 2)
      validatePayrollSnapshotRequest req `shouldSatisfy` isLeft

    it "accepts reasonable ranges" $ do
      let req = PayrollSnapshotRequest (fromGregorian 2025 1 1) (fromGregorian 2025 12 31)
      validatePayrollSnapshotRequest req `shouldSatisfy` isRight
