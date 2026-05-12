-- | Payroll calculation — income tax, social tax, vacation, sick leave, bonuses
-- Matches tests in test/Test.hs: performs Russian payroll tax calculations
module Core.Payroll.Calculation
  ( calcIncomeTax
  , calcSocialTax
  , calcNetSalaryFromGross
  , calcVacationDays
  , calcSickLeavePay
  , calcYearEndBonus
  , calcAdvanceAmount
  , calcMonthlyAdvance
  , calcTotalCompensation
  ) where

import Data.Time (Day, diffDays)

-- | Calculate progressive income tax (НДФЛ)
-- Brackets: 13% ≤500k, 15% ≤3.5M, 18% ≤5M, 20% >5M
calcIncomeTax :: Double -> Double
calcIncomeTax salary
  | salary <= 0 = 0
  | salary <= 500000 = salary * 0.13
  | salary <= 3500000 = 65000 + (salary - 500000) * 0.15
  | salary <= 5000000 = 65000 + 450000 + (salary - 3500000) * 0.18
  | otherwise = 65000 + 450000 + 270000 + (salary - 5000000) * 0.20

-- | Calculate social tax (страховые взносы)
-- 30% up to cap of 876000, then 0% above cap
calcSocialTax :: Double -> Double
calcSocialTax salary
  | salary <= 0 = 0
  | salary <= 876000 = salary * 0.30
  | otherwise = 876000 * 0.30

-- | Calculate net salary (gross - income tax)
calcNetSalaryFromGross :: Double -> Double
calcNetSalaryFromGross gross = gross - calcIncomeTax gross

-- | Calculate vacation days between two dates
calcVacationDays :: Day -> Day -> Int
calcVacationDays start end = fromIntegral (diffDays end start)

-- | Calculate sick leave pay
-- first3Days: if True, employer pays (60% of avg daily * min(3, days))
-- first3Days: if False, social insurance pays (80% of avg daily * remaining)
calcSickLeavePay :: Double -> Int -> Bool -> Double
calcSickLeavePay avgDaily totalDays first3Days
  | first3Days = avgDaily * 0.60 * fromIntegral (min 3 totalDays)
  | otherwise = avgDaily * 0.80 * fromIntegral (max 0 (totalDays - 3))

-- | Calculate year-end bonus (prorated by months worked)
-- Less than 3 months: no bonus
-- 3+ months: bonus * (months / 12)
calcYearEndBonus :: Int -> Double -> Double
calcYearEndBonus monthsWorked fullBonus
  | monthsWorked < 3 = 0
  | otherwise = fullBonus * fromIntegral monthsWorked / 12.0

-- | Calculate advance amount (percentage of base salary)
calcAdvanceAmount :: Double -> Double -> Double
calcAdvanceAmount base percentage = base * percentage / 100.0

-- | Calculate monthly advance (~40% of base)
calcMonthlyAdvance :: Double -> Double
calcMonthlyAdvance base = base * 0.40

-- | Calculate total compensation (base + additional payments)
calcTotalCompensation :: Double -> Double -> Double
calcTotalCompensation base additions = base + additions