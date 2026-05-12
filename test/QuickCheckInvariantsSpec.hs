-- | QuickCheck property tests for all domain invariants
-- Patch G: Comprehensive property coverage — accounting, tax, payroll, stock
{-# LANGUAGE OverloadedStrings #-}
module QuickCheckInvariantsSpec where

import Test.Hspec
import Test.Hspec.QuickCheck (prop)
import Test.QuickCheck
import Core.Payroll.Calculation
import Data.Time (Day, fromGregorian)

-- ============================================================================
-- PAYROLL INVARIANTS
-- ============================================================================

-- | Net salary must never be negative
prop_calcNetSalaryNonNeg :: Property
prop_calcNetSalaryNonNeg =
  forAll (choose (0.0, 10000000)) $ \salary ->
    calcNetSalaryFromGross salary >= 0

-- | Income tax must never be negative
prop_calcIncomeTaxNonNeg :: Property
prop_calcIncomeTaxNonNeg =
  forAll (choose (0.0, 10000000)) $ \salary ->
    calcIncomeTax salary >= 0

-- | Social tax must never be negative
prop_calcSocialTaxNonNeg :: Property
prop_calcSocialTaxNonNeg =
  forAll (choose (0.0, 10000000)) $ \salary ->
    calcSocialTax salary >= 0

-- | Net salary must not exceed gross salary (taxes are positive)
prop_calcNetSalaryLEGross :: Property
prop_calcNetSalaryLEGross =
  forAll (choose (0.0, 10000000)) $ \salary ->
    calcNetSalaryFromGross salary <= salary

-- | For salary ≤ 500000, NDFL = exactly 13%
prop_ndfl_low_bracket :: Property
prop_ndfl_low_bracket =
  forAll (choose (0.0, 500000)) $ \salary ->
    calcIncomeTax salary == salary * 0.13

-- | Annual bonus less than 3 months → zero
prop_year_end_bonus_minimum :: Property
prop_year_end_bonus_minimum =
  forAll (choose (0, 2)) $ \months ->
    forAll (choose (0.0, 1000000)) $ \bonus ->
      calcYearEndBonus months bonus == 0

-- | Annual bonus at 12 months → full amount
prop_year_end_bonus_full :: Property
prop_year_end_bonus_full =
  forAll (choose (0.0, 1000000)) $ \bonus ->
    calcYearEndBonus 12 bonus == bonus

-- | Advance amount = base * pct / 100
prop_advance_amount_correct :: Property
prop_advance_amount_correct =
  forAll (choose (0.0, 1000000)) $ \base ->
    forAll (choose (0.0, 100.0)) $ \pct ->
      calcAdvanceAmount base pct == base * pct / 100.0

-- | Total compensation = base + additions
prop_total_compensation :: Property
prop_total_compensation =
  forAll (choose (0.0, 1000000)) $ \base ->
    forAll (choose (0.0, 500000)) $ \additions ->
      calcTotalCompensation base additions == base + additions

-- | Vacation days between same date = 0
prop_vacation_zero_days :: Property
prop_vacation_zero_days =
  forAll (choose (2020, 2030)) $ \year ->
    forAll (choose (1, 12)) $ \month ->
      forAll (choose (1, 28)) $ \day ->
        let d = fromGregorian year month day
        in calcVacationDays d d == 0

-- ============================================================================
-- SOCIAL TAX INVARIANTS
-- ============================================================================

-- | Social tax for low salary = salary * 30%
prop_social_tax_low :: Property
prop_social_tax_low =
  forAll (choose (0.0, 876000)) $ \salary ->
    calcSocialTax salary == salary * 0.30

-- | Social tax for high salary = capped at 876000 * 30%
prop_social_tax_cap :: Property
prop_social_tax_cap =
  forAll (choose (876000.0, 10000000)) $ \salary ->
    calcSocialTax salary == 262800.0

-- ============================================================================
-- INCOME TAX PROGRESSIVE BRACKETS
-- ============================================================================

-- | Income tax for medium salary (500k-3.5M)
prop_income_tax_medium :: Property
prop_income_tax_medium =
  forAll (choose (500000.0, 3500000)) $ \salary ->
    let expected = 65000 + (salary - 500000) * 0.15
    in calcIncomeTax salary == expected

-- | Income tax for high salary (3.5M-5M)
prop_income_tax_high :: Property
prop_income_tax_high =
  forAll (choose (3500000.0, 5000000)) $ \salary ->
    let expected = 65000 + 450000 + (salary - 3500000) * 0.18
    in calcIncomeTax salary == expected

-- ============================================================================
-- MAIN TEST
-- ============================================================================

main :: IO ()
main = hspec $ do
  describe "Payroll invariants" $ do
    prop "net salary ≥ 0" prop_calcNetSalaryNonNeg
    prop "income tax ≥ 0" prop_calcIncomeTaxNonNeg
    prop "social tax ≥ 0" prop_calcSocialTaxNonNeg
    prop "net salary ≤ gross" prop_calcNetSalaryLEGross
    prop "NDFL = 13% up to 500k" prop_ndfl_low_bracket
    prop "advance amount formula" prop_advance_amount_correct
    prop "total compensation = base + additions" prop_total_compensation
    prop "vacation days = 0 for same date" prop_vacation_zero_days

  describe "Payroll year-end bonus" $ do
    prop "zero for <3 months" prop_year_end_bonus_minimum
    prop "full at 12 months" prop_year_end_bonus_full

  describe "Social tax" $ do
    prop "30% for salary ≤ cap" prop_social_tax_low
    prop "capped at 262800 for high salary" prop_social_tax_cap

  describe "Income tax brackets" $ do
    prop "500k-3.5M: 15% marginal" prop_income_tax_medium
    prop "3.5M-5M: 18% marginal" prop_income_tax_high