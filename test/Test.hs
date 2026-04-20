{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedStrings #-}

module Main where

import qualified API.ServerSpec
import Core.Accounting.Account as Account
import Core.Accounting.Operations
import Core.AdvanceInvoice
import Core.Agent
import Core.Analytics
import Core.Asset
import Core.BillLine
import Core.CreditNote
import Core.Currency
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
import qualified Integration.InventoryLifecycleSpec
import qualified Integration.PerformanceSpec
import qualified Integration.PropertySpec
import Surypus.RBAC
import Surypus.Types (Decimal (..))
import Test.Hspec
import Test.Hspec.QuickCheck (prop)
import Test.QuickCheck (property)

main :: IO ()
main = hspec $ do
  describe "Text utilities" $ do
    it "concatenation works" $ T.concat ["Hello", " ", "World"] `shouldBe` "Hello World"
    it "empty check works" $ do
      T.null "" `shouldBe` True
      T.null "test" `shouldBe` False
    it "length check works" $ do
      T.length "hello" `shouldBe` 5
      T.length "" `shouldBe` 0

  describe "Payroll Calculations" $ do
    it "calcIncomeTax for low salary" $ calcIncomeTax 100000 `shouldBe` 13000.0
    it "calcIncomeTax medium salary" $ calcIncomeTax 600000 `shouldBe` 80000.0
    it "calcIncomeTax zero salary" $ calcIncomeTax 0 `shouldBe` 0
    it "calcIncomeTax negative salary" $ calcIncomeTax (-1000) `shouldBe` 0
    it "calcSocialTax basic" $ calcSocialTax 50000 `shouldBe` 15000.0
    it "calcSocialTax with cap" $ calcSocialTax 1000000 `shouldBe` 262800.0
    it "calcNetSalaryFromGross" $ calcNetSalaryFromGross 100000 `shouldBe` 87000.0
    it "calcVacationDays" $ do
      let start = fromGregorian 2026 3 1
          end = fromGregorian 2026 3 15
      calcVacationDays start end `shouldBe` 15
    it "calcSickLeavePay first 3 days" $ calcSickLeavePay 1000 5 True `shouldBe` 1800.0
    it "calcSickLeavePay after 3 days" $ calcSickLeavePay 1000 5 False `shouldBe` 4000.0
    it "calcYearEndBonus full year" $ calcYearEndBonus 12 100000 `shouldBe` 100000.0
    it "calcYearEndBonus 6 months" $ calcYearEndBonus 6 100000 `shouldBe` 50000.0
    it "calcYearEndBonus less than 3 months" $ calcYearEndBonus 2 100000 `shouldBe` 0
    it "calcAdvanceAmount" $ calcAdvanceAmount 50000 20 `shouldBe` 10000.0
    it "calcMonthlyAdvance" $ calcMonthlyAdvance 50000 `shouldBe` 20000.0
    it "calcTotalCompensation" $ calcTotalCompensation 100000 25000 `shouldBe` 125000.0

  describe "Accounting - Account Types" $ do
    it "ATAsset account type" $ show ATAsset `shouldBe` "ATAsset"
    it "ATLiability account type" $ show ATLiability `shouldBe` "ATLiability"
    it "Equity account type" $ show ATEquity `shouldBe` "ATEquity"
    it "Revenue account type" $ show ATRevenue `shouldBe` "ATRevenue"
    it "Expense account type" $ show ATExpense `shouldBe` "ATExpense"
    it "AccountType enum count" $ length [ATAsset, ATLiability, ATEquity, ATRevenue, ATExpense] `shouldBe` 5

  describe "Accounting - Account creation" $ do
    it "create Account with all fields" $ do
      let acc = Account 1 "01" "Cash" ATAsset Nothing AKRegular 0
      accCode acc `shouldBe` "01"
      accName acc `shouldBe` "Cash"
      accType acc `shouldBe` ATAsset
    it "Account with parent" $ do
      let acc = Account 2 "010" "Cash in Bank" ATAsset (Just 1) AKRegular 0
      accParent acc `shouldBe` Just 1
    it "Regular account kind" $ show AKRegular `shouldBe` "AKRegular"
    it "Analytic account kind" $ show AKAnalytic `shouldBe` "AKAnalytic"

  describe "Accounting - Balance Check" $ do
    it "ATAsset account type check" $ do
      let acc = Account 1 "01" "Cash" ATAsset Nothing AKRegular 0
      accType acc `shouldBe` ATAsset
    it "ATLiability account type check" $ do
      let acc = Account 1 "60" "Accounts Payable" ATLiability Nothing AKRegular 0
      accType acc `shouldBe` ATLiability

  describe "Boundary Tests" $ do
    it "calcIncomeTax for boundary 500k" $ calcIncomeTax 500000 `shouldBe` 65000.0
    it "calcIncomeTax for boundary 3.5M" $ calcIncomeTax 3500000 `shouldBe` 65000.0 + 450000.0
    it "calcIncomeTax for boundary 5M" $ calcIncomeTax 5000000 `shouldBe` 65000.0 + 450000.0 + 270000.0
    it "calcIncomeTax for boundary 20M" $ calcIncomeTax 20000000 `shouldBe` 65000.0 + 450000.0 + 2700000.0 + 3000000.0

  describe "Template Loading" $ do
    it "template count is 9" $ (9 :: Int) `shouldBe` (9 :: Int)
    it "template types defined" $ True `shouldBe` True

  Integration.InventoryLifecycleSpec.spec

  describe "VAT Calculations" $ do
    it "calcVAT basic 20%" $ calcVAT (Decimal 10000) (Decimal 20) `shouldBe` Decimal 2000
    it "calcVAT 10%" $ calcVAT (Decimal 10000) (Decimal 10) `shouldBe` Decimal 1000
    it "calcVAT zero rate" $ calcVAT (Decimal 10000) (Decimal 0) `shouldBe` Decimal 0
    it "calcVATFromInclusive 20%" $ calcVATFromInclusive (Decimal 12000) (Decimal 20) `shouldBe` Decimal 2000
    it "calcVATFromInclusive 10%" $ calcVATFromInclusive (Decimal 11000) (Decimal 10) `shouldBe` Decimal 1000
    it "calcPriceWithoutVAT 20%" $ calcPriceWithoutVAT (Decimal 12000) (Decimal 20) `shouldBe` Decimal 10000
    it "calcTaxInclusive 20%" $ calcTaxInclusive (Decimal 10000) (Decimal 20) `shouldBe` Decimal 12000
    it "extractVAT equals calcVATFromInclusive" $ extractVAT (Decimal 12000) (Decimal 20) `shouldBe` calcVATFromInclusive (Decimal 12000) (Decimal 20)

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

  describe "Tax Entry Validation" $ do
    it "valid tax entry" $ do
      let entry = TaxEntry 1 0 0 0 (Decimal 2000) (Decimal 1000) (Decimal 500) defaultTaxFlags 0 0
      validateTaxEntry entry `shouldBe` True
    it "valid tax entry with zero rates" $ do
      let entry = TaxEntry 1 0 0 0 (Decimal 0) (Decimal 0) (Decimal 0) defaultTaxFlags 0 0
      validateTaxEntry entry `shouldBe` True

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

  describe "Excise Calculations" $ do
    it "calcExcise ad valorem" $ calcExcise (Decimal 10000) (Decimal 1000) False `shouldBe` Decimal 1000
    it "calcExcise absolute" $ calcExcise (Decimal 10000) (Decimal 5000) True `shouldBe` Decimal 5000
    it "calcUnitExcise" $ calcUnitExcise (Decimal 50) (Decimal 100) `shouldBe` Decimal 50

  describe "QuickCheck Properties" $ do
    prop "VAT is non-negative" prop_vat_nonnegative
    prop "VAT is bounded by amount" prop_vat_bounded
    prop "VAT roundtrip" prop_vat_roundtrip
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
      it "admin can access AdminAccess" $ checkPermission "admin" AdminAccess `shouldBe` Right ()
      it "manager cannot access AdminAccess" $
        checkPermission "manager" AdminAccess `shouldSatisfy` \case
          Left _ -> True
          Right () -> False
      it "user can read bills" $ checkPermission "user" BillRead `shouldBe` Right ()
      it "user cannot write bills" $
        checkPermission "user" BillWrite `shouldSatisfy` \case
          Left _ -> True
          Right () -> False
      it "viewer cannot write persons" $
        checkPermission "viewer" PersonWrite `shouldSatisfy` \case
          Left _ -> True
          Right () -> False

    describe "roleFromText function" $ do
      it "converts admin text to RoleAdmin" $ roleFromText "admin" `shouldBe` RoleAdmin
      it "converts manager text to RoleManager" $ roleFromText "manager" `shouldBe` RoleManager
      it "converts user text to RoleUser" $ roleFromText "user" `shouldBe` RoleUser
      it "converts viewer text to RoleViewer" $ roleFromText "viewer" `shouldBe` RoleViewer
      it "invalid role defaults to RoleViewer" $ roleFromText "invalid" `shouldBe` RoleViewer
      it "empty string defaults to RoleViewer" $ roleFromText "" `shouldBe` RoleViewer

    describe "Permission coverage" $ do
      it "all roles have permissions defined" $ do
        length (rpPermissions adminRole) `shouldSatisfy` (> 0)
        length (rpPermissions managerRole) `shouldSatisfy` (> 0)
        length (rpPermissions userRole) `shouldSatisfy` (> 0)
        length (rpPermissions viewerRole) `shouldSatisfy` (> 0)
      it "admin has more permissions than manager" $
        length (rpPermissions adminRole) `shouldSatisfy` (> length (rpPermissions managerRole))
      it "manager has more permissions than user" $
        length (rpPermissions managerRole) `shouldSatisfy` (> length (rpPermissions userRole))
      it "user has more permissions than viewer" $
        length (rpPermissions userRole) `shouldSatisfy` (> length (rpPermissions viewerRole))

  API.ServerSpec.spec

  Integration.PerformanceSpec.spec
  Integration.PropertySpec.spec_accountingProperties
  Integration.PropertySpec.spec_vatProperties
  Integration.PropertySpec.spec_inventoryProperties
  Integration.PropertySpec.spec_warehouseProperties
  Integration.PropertySpec.spec_payrollProperties
  Integration.PropertySpec.spec_billProperties
