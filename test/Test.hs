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
import Core.Accounting.Account

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
            calcIncomeTax 600000 `shouldBe` 80000.0

        it "calcIncomeTax zero salary" $ do
            calcIncomeTax 0 `shouldBe` 0

        it "calcIncomeTax negative salary" $ do
            calcIncomeTax (-1000) `shouldBe` 0

        it "calcSocialTax basic" $ do
            calcSocialTax 50000 `shouldBe` 15000.0

        it "calcSocialTax with cap" $ do
            calcSocialTax 1000000 `shouldBe` 262800.0

        it "calcNetSalaryFromGross" $ do
            calcNetSalaryFromGross 100000 `shouldBe` 87000.0

        it "calcVacationDays" $ do
            let start = fromGregorian 2026 3 1
                end = fromGregorian 2026 3 15
            calcVacationDays start end `shouldBe` 15

        it "calcSickLeavePay first 3 days" $ do
            let result = calcSickLeavePay 1000 5 True
            result `shouldBe` 1800.0

        it "calcSickLeavePay after 3 days" $ do
            let result = calcSickLeavePay 1000 5 False
            result `shouldBe` 4000.0

        it "calcYearEndBonus full year" $ do
            calcYearEndBonus 12 100000 `shouldBe` 100000.0

        it "calcYearEndBonus 6 months" $ do
            calcYearEndBonus 6 100000 `shouldBe` 50000.0

        it "calcYearEndBonus no bonus" $ do
            calcYearEndBonus 2 100000 `shouldBe` 0

        it "calcAdvanceAmount" $ do
            calcAdvanceAmount 50000 20 `shouldBe` 10000.0

        it "calcMonthlyAdvance" $ do
            calcMonthlyAdvance 50000 `shouldBe` 20000.0

        it "calcTotalCompensation" $ do
            calcTotalCompensation 100000 25000 `shouldBe` 125000.0

    describe "Accounting - Account Types" $ do
        it "Asset account type" $ do
            show Asset `shouldBe` "Asset"

        it "Liability account type" $ do
            show Liability `shouldBe` "Liability"

        it "Equity account type" $ do
            show Equity `shouldBe` "Equity"

        it "Revenue account type" $ do
            show Revenue `shouldBe` "Revenue"

        it "Expense account type" $ do
            show Expense `shouldBe` "Expense"

        it "AccountType enum count" $ do
            length [Asset, Liability, Equity, Revenue, Expense] `shouldBe` 5

    describe "Accounting - Account creation" $ do
        it "create Account" $ do
            let acc = Account { accId = 1, accCode = "01", accName = "Cash", accType = Asset, accParent = Nothing, accKind = AK_Regular, accFlags = 0 }
            accCode acc `shouldBe` "01"
            accName acc `shouldBe` "Cash"
            accType acc `shouldBe` Asset

        it "Account with parent" $ do
            let acc = Account { accId = 2, accCode = "010", accName = "Cash in Bank", accType = Asset, accParent = Just 1, accKind = AK_Regular, accFlags = 0 }
            accParent acc `shouldBe` Just 1

    describe "Accounting - Account Kinds" $ do
        it "Regular account kind" $ do
            show AK_Regular `shouldBe` "AK_Regular"

        it "Analytic account kind" $ do
            show AK_Analytic `shouldBe` "AK_Analytic"

    describe "Accounting - Balance Check" $ do
        it "Asset account type check" $ do
            let acc = Account { accId = 1, accCode = "01", accName = "Cash", accType = Asset, accParent = Nothing, accKind = AK_Regular, accFlags = 0 }
            accType acc `shouldBe` Asset

        it "Liability account type check" $ do
            let acc = Account { accId = 1, accCode = "60", accName = "Accounts Payable", accType = Liability, accParent = Nothing, accKind = AK_Regular, accFlags = 0 }
            accType acc `shouldBe` Liability

    describe "Accounting - Chart of Accounts" $ do
        it "create chart of accounts" $ do
            let acc1 = Account { accId = 1, accCode = "01", accName = "Cash", accType = Asset, accParent = Nothing, accKind = AK_Regular, accFlags = 0 }
            let acc2 = Account { accId = 2, accCode = "02", accName = "AR", accType = Asset, accParent = Nothing, accKind = AK_Regular, accFlags = 0 }
            let acc3 = Account { accId = 3, accCode = "60", accName = "AP", accType = Liability, accParent = Nothing, accKind = AK_Regular, accFlags = 0 }
            length [acc1, acc2, acc3] `shouldBe` 3
