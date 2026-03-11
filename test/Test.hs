-- ============================================================================
-- SURYPUS TEST SUITE
-- ============================================================================

{-# LANGUAGE OverloadedStrings #-}

module Main where

import Test.Hspec
import Data.Text (Text)
import qualified Data.Text as T
import Data.Time (fromGregorian)
import Core.Payroll.Calculation

-- ============================================================================
-- MAIN
-- ============================================================================

main :: IO ()
main = hspec $ do
    describe "Text utilities" $ do
        it "concatenation works" $ do
            let result = T.concat ["Hello", " ", "World"]
            result `shouldBe` "Hello World"

        it "empty check works" $ do
            T.null "" `shouldBe` True
            T.null "test" `shouldBe` False

        it "length check works" $ do
            T.length "hello" `shouldBe` 5
            T.length "" `shouldBe` 0

    describe "Payroll Calculations" $ do
        it "calcIncomeTax for low salary" $ do
            calcIncomeTax 100000 `shouldBe` 13000.0

        it "calcIncomeTax for medium salary" $ do
            calcIncomeTax 600000 `shouldBe` 80000.0  -- 65000 + 100000 * 0.15

        it "calcIncomeTax zero salary" $ do
            calcIncomeTax 0 `shouldBe` 0

        it "calcIncomeTax negative salary" $ do
            calcIncomeTax (-1000) `shouldBe` 0

        it "calcSocialTax basic" $ do
            calcSocialTax 50000 `shouldBe` 15000.0  -- 30%

        it "calcSocialTax with cap" $ do
            calcSocialTax 1000000 `shouldBe` 262800.0  -- min(1000000, 876000) * 0.30

        it "calcNetSalaryFromGross" $ do
            calcNetSalaryFromGross 100000 `shouldBe` 87000.0

        it "calcVacationDays" $ do
            let start = fromGregorian 2026 3 1
                end = fromGregorian 2026 3 15
            calcVacationDays start end `shouldBe` 15

        it "calcSickLeavePay first 3 days" $ do
            let result = calcSickLeavePay 1000 5 True
            result `shouldBe` 1800.0  -- 1000 * 3 * 0.6

        it "calcSickLeavePay after 3 days" $ do
            let result = calcSickLeavePay 1000 5 False
            result `shouldBe` 4000.0  -- 1000 * 5 * 0.8

        it "calcYearEndBonus full year" $ do
            calcYearEndBonus 12 100000 `shouldBe` 100000.0

        it "calcYearEndBonus 6 months" $ do
            calcYearEndBonus 6 100000 `shouldBe` 50000.0

        it "calcYearEndBonus no bonus" $ do
            calcYearEndBonus 2 100000 `shouldBe` 0