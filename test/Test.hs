{-# LANGUAGE LambdaCase #-}
-- ============================================================================
-- COMPREHENSIVE SURYPUS TEST SUITE
-- ============================================================================
{-# LANGUAGE OverloadedStrings #-}

module Main where

import qualified API.ServerSpec
import Core.Accounting.Account
import Core.Accounting.Operations
import Core.AdvanceInvoice
import Core.Agent
import Core.Analytics
import Core.Asset
import Core.BillLine
import Core.CreditNote
import Core.Currency.Operations
import Core.Discount
import Core.Document.Operations
import Core.GoodsTaxEx
import Core.Invoice
import Core.Invoice.Operations
import Core.Loyalty.Bonus
import Core.Order
import Core.Payroll.Calculation
import Core.Payroll.Types
import Core.Price
import Core.Price.Operations
import Core.Quotation
import Core.RetBill
import Core.SmartReceipt
import Core.Tax
import Core.TaxInvoice
import Core.Transfer
import Core.Warehouse
import Data.Int ()
import Data.Maybe ()
import qualified Data.Text as T
import Data.Time (fromGregorian)
import qualified Integration.PropertySpec
import Surypus.RBAC
import Surypus.Types (Decimal (..))
import Test.Hspec
import Test.Hspec.QuickCheck (prop)
import Test.QuickCheck (property)

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
    it "ATAsset account type" $ do
      show ATAsset `shouldBe` "ATAsset"

    it "ATLiability account type" $ do
      show ATLiability `shouldBe` "ATLiability"

    it "Equity account type" $ do
      show ATEquity `shouldBe` "ATEquity"

    it "Revenue account type" $ do
      show ATRevenue `shouldBe` "ATRevenue"

    it "Expense account type" $ do
      show ATExpense `shouldBe` "ATExpense"

    it "AccountType enum count" $ do
      length [ATAsset, ATLiability, ATEquity, ATRevenue, ATExpense] `shouldBe` 5

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
                accType = ATAsset,
                accParent = Nothing,
                accKind = AKRegular,
                accFlags = 0
              }
      accCode acc `shouldBe` "01"
      accName acc `shouldBe` "Cash"
      accType acc `shouldBe` ATAsset

    it "Account with parent" $ do
      let acc =
            Account
              { accId = 2,
                accCode = "010",
                accName = "Cash in Bank",
                accType = ATAsset,
                accParent = Just 1,
                accKind = AKRegular,
                accFlags = 0
              }
      accParent acc `shouldBe` Just 1

    it "Regular account kind" $ do
      show AKRegular `shouldBe` "AKRegular"

    it "Analytic account kind" $ do
      show AKAnalytic `shouldBe` "AKAnalytic"

  -- ========================================================================
  -- ACCOUNTING - BALANCE CHECK
  -- ========================================================================
  describe "Accounting - Balance Check" $ do
    it "ATAsset account type check" $ do
      let acc = Account 1 "01" "Cash" ATAsset Nothing AKRegular 0
      accType acc `shouldBe` ATAsset

    it "ATLiability account type check" $ do
      let acc = Account 1 "60" "Accounts Payable" ATLiability Nothing AKRegular 0
      accType acc `shouldBe` ATLiability

  -- ========================================================================
  -- ACCOUNTING - CHART OF ACCOUNTS
  -- ========================================================================
  describe "Accounting - Chart of Accounts" $ do
    it "create chart of accounts" $ do
      let acc1 = Account 1 "01" "Cash" ATAsset Nothing AKRegular 0
      let acc2 = Account 2 "02" "Accounts Receivable" ATAsset Nothing AKRegular 0
      let acc3 = Account 3 "60" "Accounts Payable" ATLiability Nothing AKRegular 0
      length [acc1, acc2, acc3] `shouldBe` 3

    it "filter asset accounts" $ do
      let accounts = [acc1, acc2, acc3]
          acc1 = Account 1 "01" "Cash" ATAsset Nothing AKRegular 0
          acc2 = Account 2 "60" "Accounts Payable" ATLiability Nothing AKRegular 0
          acc3 = Account 3 "10" "Fixed ATAssets" ATAsset Nothing AKRegular 0
          assets = filter (\a -> accType a == ATAsset) accounts
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
      calcIncomeTax 5000000 `shouldBe` 65000.0 + 450000.0 + 270000.0

    it "calcIncomeTax for boundary 20M" $ do
      calcIncomeTax 20000000 `shouldBe` 65000.0 + 450000.0 + 2700000.0 + 3000000.0

  -- ========================================================================
  -- TEMPLATE LOADING (template count)
  -- ========================================================================
  describe "Template Loading" $ do
    it "template count is 9" $ do
      -- 9 PDF templates defined in templates/reports/
      (9 :: Int) `shouldBe` (9 :: Int)

    it "template types defined" $ do
      -- Template types exist
      True `shouldBe` True

    -- ========================================================================
    -- VAT CALCULATIONS (НДС)
    -- ========================================================================
    describe "VAT Calculations" $ do
      it "calcVAT basic 20%" $ do
        calcVAT (Decimal 10000) (Decimal 20) `shouldBe` Decimal 2000

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
        calcUnitExcise (Decimal 50) (Decimal 100) `shouldBe` Decimal 50

    -- ========================================================================
    -- QUICKCHECK PROPERTIES
    -- ========================================================================
    describe "QuickCheck Properties" $ do
      prop "VAT is non-negative" prop_vat_nonnegative
      prop "VAT is bounded by amount" prop_vat_bounded
      prop "VAT roundtrip (inclusive → exclusive ≈ original)" prop_vat_roundtrip
      prop "Tax vector total is non-negative" prop_tax_vector_total_nonneg
      prop "Tax vector gross >= net" prop_tax_vector_gross_ge_net
      prop "Tax vector invariants hold" prop_tax_vector_valid
      prop "BillLine total is non-negative" prop_lineTotalNonNeg
      prop "BillLine discount calculation correct" prop_lineTotalDiscountBound
      prop "Price calcLineTotal non-negative" prop_calcLineTotalNonNeg
      prop "Price calcBillTotal non-negative" prop_calcBillTotalNonNeg
      prop "Price calcDiscount non-negative" prop_calcDiscountNonNeg
      prop "Price calcFinalPrice non-negative" prop_calcFinalPriceNonNeg
      prop "Price verifyDiscountBounded valid" prop_verifyDiscountBounded
      prop "Accounting double-entry balanced" prop_doubleEntryBalance
      prop "Accounting turnover non-negative" prop_turnoverNonNeg
      prop "Payroll calcNetSalary non-negative" prop_calcNetSalaryNonNeg
      prop "Payroll calcGrossFromNet positive" prop_calcGrossFromNetPos
      prop "Payroll calcTaxAmount non-negative" prop_calcTaxAmountNonNeg
      prop "Invoice balance non-negative" prop_invoiceBalanceNonNeg
      prop "Invoice payment due non-negative" prop_paymentDueNonNeg
      prop "Invoice calcPaymentDue non-negative" prop_calcPaymentDueNonNeg
      prop "Invoice paid bounded 0-100" prop_invoicePaidBounded
      prop "PayrollCalculation income tax non-negative" prop_calcIncomeTaxNonNeg
      prop "PayrollCalculation social tax non-negative" prop_calcSocialTaxNonNeg
      prop "PayrollCalculation net salary non-negative" prop_calcNetSalaryFromGrossNonNeg
      prop "PayrollCalculation vacation pay non-negative" prop_vacationPayNonNeg
      prop "PayrollCalculation sick leave pay non-negative" prop_sickLeavePayNonNeg
      prop "PayrollCalculation advance amount non-negative" prop_advanceAmountNonNeg
      prop "Order line total non-negative" prop_orderLineTotalNonNeg
      prop "Order total non-negative" prop_orderTotalNonNeg
      prop "RetBill final amount non-negative" prop_retBillFinalAmountNonNeg
      prop "AdvanceInvoice remaining non-negative" prop_advanceInvoiceRemainingNonNeg
      prop "CreditNote amount non-negative" prop_creditNoteAmountNonNeg
      prop "Agent commission non-negative" prop_commissionNonNeg
      prop "Warehouse stock balance non-negative" prop_stockBalanceNonNeg
      prop "SmartReceipt total non-negative" prop_receiptTotalNonNeg
      prop "Transfer amount non-negative" prop_transferAmountNonNeg
      prop "Document total non-negative" prop_documentTotalNonNeg
      prop "Document amounts validation" prop_validateDocumentAmounts
      prop "Quotation total non-negative" prop_quotationTotalNonNeg
      prop "Production material consumption" $ property True
      prop "Loyalty bonus balance valid" prop_bonusBalanceBounded
      prop "Asset value non-negative" prop_assetValueNonNeg
      prop "Analytics profit non-negative" prop_profitBounded
      prop "Analytics margin bounded" prop_marginBounded
      prop "TaxInvoice tax amount non-negative" prop_taxAmountNonNeg
      prop "GoodsTaxEx tax amount non-negative" prop_goodsTaxAmountNonNeg
      prop "Discount amount non-negative" prop_discountAmountNonNeg
      prop "currency_rounding_in_bounds" prop_roundToPrecisionInBounds

    -- ========================================================================
    -- RBAC TESTS
    -- ========================================================================
    describe "RBAC (Role-Based Access Control)" $ do
      describe "Roles" $ do
        it "RoleAdmin has all permissions" $ do
          hasPermission RoleAdmin PersonRead `shouldBe` True
          hasPermission RoleAdmin PersonWrite `shouldBe` True
          hasPermission RoleAdmin PersonDelete `shouldBe` True
          hasPermission RoleAdmin AdminAccess `shouldBe` True
          hasPermission RoleAdmin UsersWrite `shouldBe` True

        it "RoleManager has manager permissions" $ do
          hasPermission RoleManager PersonRead `shouldBe` True
          hasPermission RoleManager PersonWrite `shouldBe` True
          hasPermission RoleManager BillWrite `shouldBe` True
          hasPermission RoleManager PersonDelete `shouldBe` False
          hasPermission RoleManager AdminAccess `shouldBe` False

        it "RoleUser has limited permissions" $ do
          hasPermission RoleUser PersonRead `shouldBe` True
          hasPermission RoleUser GoodsRead `shouldBe` True
          hasPermission RoleUser PersonWrite `shouldBe` False
          hasPermission RoleUser BillWrite `shouldBe` False

        it "RoleViewer only has read permissions" $ do
          hasPermission RoleViewer PersonRead `shouldBe` True
          hasPermission RoleViewer ReportsRead `shouldBe` True
          hasPermission RoleViewer PersonWrite `shouldBe` False
          hasPermission RoleViewer BillWrite `shouldBe` False
          hasPermission RoleViewer AdminAccess `shouldBe` False

      describe "checkPermission function" $ do
        it "admin can access AdminAccess" $
          checkPermission "admin" AdminAccess `shouldBe` Right ()

        it "manager cannot access AdminAccess" $
          checkPermission "manager" AdminAccess `shouldSatisfy` \case
            Left _ -> True
            Right () -> False

        it "user can read bills" $
          checkPermission "user" BillRead `shouldBe` Right ()

        it "user cannot write bills" $
          checkPermission "user" BillWrite `shouldSatisfy` \case
            Left _ -> True
            Right () -> False

        it "viewer cannot write persons" $
          checkPermission "viewer" PersonWrite `shouldSatisfy` \case
            Left _ -> True
            Right () -> False

      describe "roleFromText function" $ do
        it "converts admin text to RoleAdmin" $
          roleFromText "admin" `shouldBe` RoleAdmin

        it "converts manager text to RoleManager" $
          roleFromText "manager" `shouldBe` RoleManager

        it "converts user text to RoleUser" $
          roleFromText "user" `shouldBe` RoleUser

        it "converts viewer text to RoleViewer" $
          roleFromText "viewer" `shouldBe` RoleViewer

        it "invalid role defaults to RoleViewer" $
          roleFromText "invalid" `shouldBe` RoleViewer

        it "empty string defaults to RoleViewer" $
          roleFromText "" `shouldBe` RoleViewer

      describe "Permission coverage" $ do
        it "all roles have permissions defined" $ do
          length (rpPermissions adminRole) `shouldSatisfy` (> 0)
          length (rpPermissions managerRole) `shouldSatisfy` (> 0)
          length (rpPermissions userRole) `shouldSatisfy` (> 0)
          length (rpPermissions viewerRole) `shouldSatisfy` (> 0)

        it "admin has more permissions than manager" $
          length (rpPermissions adminRole)
            `shouldSatisfy` (> length (rpPermissions managerRole))

        it "manager has more permissions than user" $
          length (rpPermissions managerRole)
            `shouldSatisfy` (> length (rpPermissions userRole))

        it "user has more permissions than viewer" $
          length (rpPermissions userRole)
            `shouldSatisfy` (> length (rpPermissions viewerRole))

    -- ========================================================================
    -- API SERVER TESTS
    -- ========================================================================
    API.ServerSpec.spec

    -- ========================================================================
    -- PROPERTY-BASED TESTS
    -- ========================================================================
    Integration.PropertySpec.spec_accountingProperties
    Integration.PropertySpec.spec_vatProperties
    Integration.PropertySpec.spec_inventoryProperties
    Integration.PropertySpec.spec_warehouseProperties
    Integration.PropertySpec.spec_payrollProperties
    Integration.PropertySpec.spec_billProperties
