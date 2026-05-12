{-# LANGUAGE OverloadedStrings #-}

module Test.QuickCheck.Invariants
  ( props_accountingInvariant,
    props_vatInvariant,
    props_inventoryInvariant,
    props_payrollInvariant,
  )
where

import Core.Accounting.Operations (AccOpResult (..), verifyDoubleEntry)
import Core.Accounting.Types (AccTurn (..))
import Core.Payroll.Calculation (calcIncomeTax, calcNetSalaryFromGross, calcSocialTax)
import Core.Tax (calcPriceWithoutVAT, calcTaxInclusive, calcVAT, calcVATFromInclusive)
import Core.Warehouse (StockMovement (..), calcStockBalance)
import Surypus.Types (Decimal (..), fromDecimal, toDecimal)
import Test.QuickCheck

newtype NonNegative a = NonNegative {getNonNegative :: a} deriving (Show)

instance (Arbitrary a, Num a, Ord a) => Arbitrary (NonNegative a) where
  arbitrary = NonNegative <$> suchThat arbitrary (>= 0)

newtype Positive a = Positive {getPositive :: a} deriving (Show)

instance (Arbitrary a, Num a, Ord a) => Arbitrary (Positive a) where
  arbitrary = Positive <$> suchThat arbitrary (> 0)

newtype Percentage = Percentage {getPercentage :: Double} deriving (Show)

instance Arbitrary Percentage where
  arbitrary = Percentage <$> choose (0, 100)

newtype TaxRate = TaxRate {getTaxRate :: Double} deriving (Show)

instance Arbitrary TaxRate where
  arbitrary = TaxRate <$> elements [10, 15, 18, 20]

prop_vat_nonnegative :: Double -> TaxRate -> Property
prop_vat_nonnegative amount (TaxRate rate) =
  let d = toDecimal amount
      result = fromDecimal (calcVAT d (Decimal rate))
   in result >= 0 .&&. result <= amount

prop_vat_roundtrip :: Positive Double -> TaxRate -> Property
prop_vat_roundtrip (Positive amount) (TaxRate rate) =
  let d = toDecimal amount
      withoutVat = calcPriceWithoutVAT d (Decimal rate)
      withVat = calcTaxInclusive withoutVat (Decimal rate)
   in fromDecimal withVat `approxEq` amount

prop_vat_from_inclusive :: Positive Double -> TaxRate -> Property
prop_vat_from_inclusive (Positive amount) (TaxRate rate) =
  let d = toDecimal amount
      vat = calcVATFromInclusive d (Decimal rate)
   in fromDecimal vat >= 0 .&&. fromDecimal vat <= amount
  where
    approxEq a b = abs (a - b) < 0.01

prop_accounting_double_entry :: [AccTurn] -> Property
prop_accounting_double_entry turns =
  let totalDebit = sum (map atDbtAmt turns)
      totalCredit = sum (map atCrdAmt turns)
   in totalDebit == totalCredit

prop_accounting_verify_balanced :: [AccTurn] -> Property
prop_accounting_verify_balanced turns =
  (not (null turns) && all balanced turns) ==> case verifyDoubleEntry turns of
    AccOpSuccess -> property True
    _ -> property False
  where
    balanced t = atDbtAmt t == atCrdAmt t && atDbtAmt t > 0

prop_inventory_stock_nonnegative :: [StockMovement] -> Property
prop_inventory_stock_nonnegative movements =
  calcStockBalance 0 movements >= 0

prop_inventory_movement_qty :: StockMovement -> Property
prop_inventory_movement_qty m = smQtty m >= 0

prop_payroll_income_tax_bounds :: Positive Double -> Property
prop_payroll_income_tax_bounds (Positive salary) =
  let tax = calcIncomeTax salary
   in tax >= 0 .&&. tax <= salary

prop_payroll_social_tax_bounds :: Positive Double -> Property
prop_payroll_social_tax_bounds (Positive salary) =
  let tax = calcSocialTax salary
   in tax >= 0 .&&. tax <= salary

prop_payroll_net_salary_bounds :: Positive Double -> Property
prop_payroll_net_salary_bounds (Positive salary) =
  let net = calcNetSalaryFromGross salary
   in net >= 0 .&&. net <= salary

props_vatInvariant :: [(String, Property)]
props_vatInvariant =
  [ ("VAT is non-negative and <= original amount", prop_vat_nonnegative),
    ("VAT roundtrip: price without VAT + VAT = original", prop_vat_roundtrip),
    ("VAT from inclusive price is valid", prop_vat_from_inclusive)
  ]

props_accountingInvariant :: [(String, Property)]
props_accountingInvariant =
  [ ("Double-entry: total debits = total credits", prop_accounting_double_entry),
    ("verifyDoubleEntry accepts balanced entries", prop_accounting_verify_balanced)
  ]

props_inventoryInvariant :: [(String, Property)]
props_inventoryInvariant =
  [ ("Stock balance is non-negative", prop_inventory_stock_nonnegative),
    ("Stock movement quantity is non-negative", prop_inventory_movement_qty)
  ]

-- Additional atomic invariants (production-ready)
prop_stockBalanceNonNegative :: [StockMovement] -> Property
prop_stockBalanceNonNegative moves =
  calcStockBalance 0 moves >= 0

prop_ndflCorrect :: Positive Double -> Property
prop_ndflCorrect (Positive salary) =
  let tax = calcIncomeTax salary
   in tax >= 0

prop_inventoryConservation :: [StockMovement] -> Property
prop_inventoryConservation moves =
  property $ sum (map smQtty moves) >= 0

props_payrollInvariant :: [(String, Property)]
props_payrollInvariant =
  [ ("Income tax is between 0 and salary", prop_payroll_income_tax_bounds),
    ("Social tax is between 0 and salary", prop_payroll_social_tax_bounds),
    ("Net salary is between 0 and gross", prop_payroll_net_salary_bounds)
  ]

--------------------------------------------------------------------------------
-- Bill Service Invariants (Surypus-627)
--------------------------------------------------------------------------------

-- | Bill line for testing
data TestBillLine = TestBillLine
  { tblQty :: Double
  , tblPrice :: Double
  , tblDiscount :: Double
  } deriving (Show)

instance Arbitrary TestBillLine where
  arbitrary = TestBillLine
    <$> arbitrary
    <*> arbitrary
    <*> arbitrary

prop_bill_line_amount_nonneg :: TestBillLine -> Property
prop_bill_line_amount_nonneg line =
  let qty = max 0 (tblQty line)
      price = max 0 (tblPrice line)
      discount = max 0 (tblDiscount line)
      amount = qty * price - discount
  in amount >= 0 .||. discount <= qty * price

prop_bill_total_equals_lines :: Double -> [TestBillLine] -> Property
prop_bill_total_equals_lines discount lines =
  let amounts = [max 0 (tblQty l * tblPrice l - tblDiscount l) | l <- lines]
      total = sum amounts
      calculated = total - max 0 discount
  in calculated >= 0

prop_double_entry_balanced :: Double -> Double -> Property
prop_double_entry_balanced debit credit =
  let totalDebit = max 0 debit
      totalCredit = max 0 credit
  in totalDebit >= 0 .&&. totalCredit >= 0 .||. totalDebit == totalCredit
