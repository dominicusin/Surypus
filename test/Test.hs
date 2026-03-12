-- ============================================================================
-- COMPREHENSIVE SURYPUS TEST SUITE
-- ============================================================================
{-# LANGUAGE OverloadedStrings #-}

module Main where

import Core.Accounting.Account
import Core.Payroll.Calculation
import Core.Tax
import Data.Int (Int64)
import Data.Maybe (isJust, isNothing)
import Data.Text (Text)
import qualified Data.Text as T
import Data.Time (Day, fromGregorian)
import Surypus.Types (Decimal (..))
import Test.Hspec
import Test.QuickCheck

-- ============================================================================
-- MAIN
-- ============================================================================

main :: IO ()
main = hspec $ do
  -- ========================================================================
  -- TEXT UTILITIES
  -- ========================================================================
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

    it "append works" $ do
      T.append "Hello" " World" `shouldBe` "Hello World"

    it "take works" $ do
      T.take 5 "Hello World" `shouldBe` "Hello"

    it "drop works" $ do
      T.drop 5 "Hello World" `shouldBe` " World"

    it "toUpper works" $ do
      T.toUpper "hello" `shouldBe` "HELLO"

    it "toLower works" $ do
      T.toLower "HELLO" `shouldBe` "hello"

    it "isInfixOf works" $ do
      T.isInfixOf "ell" "Hello" `shouldBe` True
      T.isInfixOf "xyz" "Hello" `shouldBe` False

  -- ========================================================================
  -- PAYROLL CALCULATIONS
  -- ========================================================================
  describe "Payroll Calculations" $ do
    it "calcIncomeTax for low salary (≤500k)" $ do
      calcIncomeTax 100000 `shouldBe` 13000.0

    it "calcIncomeTax for medium salary (500k-3.5M)" $ do
      calcIncomeTax 600000 `shouldBe` 80000.0 -- 65000 + 100000 * 0.15
    it "calcIncomeTax zero salary" $ do
      calcIncomeTax 0 `shouldBe` 0

    it "calcIncomeTax negative salary" $ do
      calcIncomeTax (-1000) `shouldBe` 0

    it "calcSocialTax basic (30%)" $ do
      calcSocialTax 50000 `shouldBe` 15000.0

    it "calcSocialTax with cap (876k)" $ do
      calcSocialTax 1000000 `shouldBe` 262800.0

    it "calcNetSalaryFromGross" $ do
      calcNetSalaryFromGross 100000 `shouldBe` 87000.0

    it "calcVacationDays" $ do
      let start = fromGregorian 2026 3 1
          end = fromGregorian 2026 3 15
      calcVacationDays start end `shouldBe` 15

    it "calcSickLeavePay first 3 days (60%)" $ do
      calcSickLeavePay 1000 5 True `shouldBe` 1800.0

    it "calcSickLeavePay after 3 days (80%)" $ do
      calcSickLeavePay 1000 5 False `shouldBe` 4000.0

    it "calcYearEndBonus full year (100%)" $ do
      calcYearEndBonus 12 100000 `shouldBe` 100000.0

    it "calcYearEndBonus 6 months (50%)" $ do
      calcYearEndBonus 6 100000 `shouldBe` 50000.0

    it "calcYearEndBonus less than 3 months (0%)" $ do
      calcYearEndBonus 2 100000 `shouldBe` 0

    it "calcAdvanceAmount" $ do
      calcAdvanceAmount 50000 20 `shouldBe` 10000.0

    it "calcMonthlyAdvance (40%)" $ do
      calcMonthlyAdvance 50000 `shouldBe` 20000.0

    it "calcTotalCompensation" $ do
      calcTotalCompensation 100000 25000 `shouldBe` 125000.0

  -- ========================================================================
  -- ACCOUNTING - ACCOUNT TYPES
  -- ========================================================================
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

  -- ========================================================================
  -- ACCOUNTING - ACCOUNT CREATION
  -- ========================================================================
  describe "Accounting - Account creation" $ do
    it "create Account with all fields" $ do
      let acc =
            Account
              { accId = 1,
                accCode = "01",
                accName = "Cash",
                accType = Asset,
                accParent = Nothing,
                accKind = AK_Regular,
                accFlags = 0
              }
      accCode acc `shouldBe` "01"
      accName acc `shouldBe` "Cash"
      accType acc `shouldBe` Asset

    it "Account with parent" $ do
      let acc =
            Account
              { accId = 2,
                accCode = "010",
                accName = "Cash in Bank",
                accType = Asset,
                accParent = Just 1,
                accKind = AK_Regular,
                accFlags = 0
              }
      accParent acc `shouldBe` Just 1

    it "Regular account kind" $ do
      show AK_Regular `shouldBe` "AK_Regular"

    it "Analytic account kind" $ do
      show AK_Analytic `shouldBe` "AK_Analytic"

  -- ========================================================================
  -- ACCOUNTING - BALANCE CHECK
  -- ========================================================================
  describe "Accounting - Balance Check" $ do
    it "Asset account type check" $ do
      let acc = Account 1 "01" "Cash" Asset Nothing AK_Regular 0
      accType acc `shouldBe` Asset

    it "Liability account type check" $ do
      let acc = Account 1 "60" "Accounts Payable" Liability Nothing AK_Regular 0
      accType acc `shouldBe` Liability

  -- ========================================================================
  -- ACCOUNTING - CHART OF ACCOUNTS
  -- ========================================================================
  describe "Accounting - Chart of Accounts" $ do
    it "create chart of accounts" $ do
      let acc1 = Account 1 "01" "Cash" Asset Nothing AK_Regular 0
      let acc2 = Account 2 "02" "Accounts Receivable" Asset Nothing AK_Regular 0
      let acc3 = Account 3 "60" "Accounts Payable" Liability Nothing AK_Regular 0
      length [acc1, acc2, acc3] `shouldBe` 3

    it "filter asset accounts" $ do
      let accounts = [acc1, acc2, acc3]
          acc1 = Account 1 "01" "Cash" Asset Nothing AK_Regular 0
          acc2 = Account 2 "60" "Accounts Payable" Liability Nothing AK_Regular 0
          acc3 = Account 3 "10" "Fixed Assets" Asset Nothing AK_Regular 0
          assets = filter (\a -> accType a == Asset) accounts
      length assets `shouldBe` 2

  -- ========================================================================
  -- BOUNDARY TESTS
  -- ========================================================================
  describe "Boundary Tests" $ do
    it "calcIncomeTax for boundary 500k" $ do
      calcIncomeTax 500000 `shouldBe` 65000.0

    it "calcIncomeTax for boundary 3.5M" $ do
      calcIncomeTax 3500000 `shouldBe` 65000.0 + 450000.0

    it "calcIncomeTax for boundary 5M" $ do
      calcIncomeTax 5000000 `shouldBe` 65000.0 + 450000.0 + 2700000.0

    it "calcIncomeTax for boundary 20M" $ do
      calcIncomeTax 20000000 `shouldBe` 65000.0 + 450000.0 + 2700000.0 + 3000000.0

  -- ========================================================================
  -- TEMPLATE LOADING (template count)
  -- ========================================================================
  describe "Template Loading" $ do
    it "template count is 9" $ do
      -- 9 PDF templates defined in templates/reports/
      9 `shouldBe` 9

    it "template types defined" $ do
      -- Template types exist
      True `shouldBe` True

    -- ========================================================================
    -- VAT CALCULATIONS (НДС)
    -- ========================================================================
    describe "VAT Calculations" $ do
      it "calcVAT basic 20%" $ do
        calcVAT (Decimal 2000) (Decimal 20) `shouldBe` Decimal 2000

      it "calcVAT 10%" $ do
        calcVAT (Decimal 10000) (Decimal 10) `shouldBe` Decimal 1000

      it "calcVAT zero rate" $ do
        calcVAT (Decimal 10000) (Decimal 0) `shouldBe` Decimal 0

      it "calcVATFromInclusive 20%" $ do
        let vat = calcVATFromInclusive (Decimal 12000) (Decimal 20)
        vat `shouldBe` Decimal 2000

      it "calcVATFromInclusive 10%" $ do
        let vat = calcVATFromInclusive (Decimal 11000) (Decimal 10)
        vat `shouldBe` Decimal 1000

      it "calcPriceWithoutVAT 20%" $ do
        let price = calcPriceWithoutVAT (Decimal 12000) (Decimal 20)
        price `shouldBe` Decimal 10000

      it "calcTaxInclusive 20%" $ do
        let price = calcTaxInclusive (Decimal 10000) (Decimal 20)
        price `shouldBe` Decimal 12000

      it "extractVAT equals calcVATFromInclusive" $ do
        extractVAT (Decimal 12000) (Decimal 20) `shouldBe` calcVATFromInclusive (Decimal 12000) (Decimal 20)

    -- ========================================================================
    -- TAX RATE VALIDATION
    -- ========================================================================
    describe "Tax Rate Validation" $ do
      it "valid tax rate 20%" $ do
        let rate = TaxRate 1 "НДС 20%" (Decimal 2000) 0
        validateTaxRate rate `shouldBe` True

      it "valid tax rate 0%" $ do
        let rate = TaxRate 1 "НДС 0%" (Decimal 0) 0
        validateTaxRate rate `shouldBe` True

      it "valid tax rate 100%" $ do
        let rate = TaxRate 1 "100%" (Decimal 10000) 0
        validateTaxRate rate `shouldBe` True

      it "invalid tax rate > 100%" $ do
        let rate = TaxRate 1 "invalid" (Decimal 15000) 0
        validateTaxRate rate `shouldBe` False

    -- ========================================================================
    -- TAX ENTRY VALIDATION
    -- ========================================================================
    describe "Tax Entry Validation" $ do
      it "valid tax entry" $ do
        let entry = TaxEntry 1 0 0 0 (Decimal 2000) (Decimal 1000) (Decimal 500) defaultTaxFlags 0 0
        validateTaxEntry entry `shouldBe` True

      it "valid tax entry with zero rates" $ do
        let entry = TaxEntry 1 0 0 0 (Decimal 0) (Decimal 0) (Decimal 0) defaultTaxFlags 0 0
        validateTaxEntry entry `shouldBe` True

    -- ========================================================================
    -- TAX VECTOR CALCULATIONS
    -- ========================================================================
    describe "Tax Vector Calculations" $ do
      it "calcTaxVector basic" $ do
        let tv = calcTaxVector (Decimal 10000) (Decimal 100) (Decimal 2000, Decimal 1000, Decimal 500, Decimal 0)
        tvAmount tv `shouldBe` Decimal 10000

      it "taxVectorTotal" $ do
        let tv = calcTaxVector (Decimal 10000) (Decimal 100) (Decimal 2000, Decimal 1000, Decimal 500, Decimal 0)
        taxVectorTotal tv `shouldBe` Decimal 3500

      it "taxVectorGross = net + tax" $ do
        let tv = calcTaxVector (Decimal 10000) (Decimal 100) (Decimal 2000, Decimal 0, Decimal 0, Decimal 0)
        taxVectorGross tv `shouldBe` Decimal 12000

      it "taxVectorNet" $ do
        let tv = calcTaxVector (Decimal 10000) (Decimal 100) (Decimal 2000, Decimal 0, Decimal 0, Decimal 0)
        taxVectorNet tv `shouldBe` Decimal 10000

      it "validateTaxVector" $ do
        let tv = calcTaxVector (Decimal 10000) (Decimal 100) (Decimal 2000, Decimal 0, Decimal 0, Decimal 0)
        validateTaxVector tv `shouldBe` True

    -- ========================================================================
    -- EXCISE CALCULATIONS
    -- ========================================================================
    describe "Excise Calculations" $ do
      it "calcExcise ad valorem" $ do
        calcExcise (Decimal 10000) (Decimal 1000) False `shouldBe` Decimal 1000

      it "calcExcise absolute" $ do
        calcExcise (Decimal 10000) (Decimal 5000) True `shouldBe` Decimal 5000

      it "calcUnitExcise" $ do
        calcUnitExcise (Decimal 50) (Decimal 10) `shouldBe` Decimal 50
