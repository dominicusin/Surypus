-- | Payroll Calculations - Salary computation logic
module Core.Payroll.Calculation where

import Data.Time (Day, diffDays)

-- ============================================================================
-- TAX CALCULATIONS
-- ============================================================================

calcIncomeTax :: Double -> Double
calcIncomeTax gross
  | gross <= 0 = 0
  | gross <= 500000 = gross * 0.13
  | gross <= 3500000 = 65000 + (gross - 500000) * 0.15
  | gross <= 5000000 = 65000 + 450000 + (gross - 3500000) * 0.18
  | gross <= 20000000 = 65000 + 450000 + 2700000 + (gross - 5000000) * 0.20
  | otherwise = 65000 + 450000 + 2700000 + 30000000 + (gross - 20000000) * 0.22

calcNDFL :: Double -> Double
calcNDFL = calcIncomeTax

-- ============================================================================
-- SOCIAL CONTRIBUTIONS
-- ============================================================================

calcSocialTax :: Double -> Double
calcSocialTax gross
  | gross <= 0 = 0
  | otherwise = min gross 876000 * 0.30 -- 30% up to limit

calcInsurancePremium :: Double -> Double
calcInsurancePremium gross = gross * 0.022 -- 2.2% for medical

calcPensionContribution :: Double -> Double
calcPensionContribution gross
  | gross <= 0 = 0
  | otherwise = min gross 876000 * 0.22 -- 22% to pension

-- ============================================================================
-- NET SALARY CALCULATION
-- ============================================================================

calcNetSalaryFromGross :: Double -> Double
calcNetSalaryFromGross gross = gross - calcIncomeTax gross

calcTotalCompensation :: Double -> Double -> Double
calcTotalCompensation salary bonuses = salary + bonuses

-- ============================================================================
-- VACATION CALCULATIONS
-- ============================================================================

calcVacationDays :: Day -> Day -> Int
calcVacationDays start end = fromIntegral (diffDays end start) + 1

calcVacationPay :: Double -> Int -> Double
calcVacationPay dailyRate days = dailyRate * fromIntegral days

calcAverageDailyEarnings :: Double -> Int -> Double
calcAverageDailyEarnings totalEarnings workDays
  | workDays > 0 = totalEarnings / fromIntegral workDays
  | otherwise = 0

-- ============================================================================
-- SICK LEAVE CALCULATIONS
-- ============================================================================

calcSickLeavePay :: Double -> Int -> Bool -> Double
calcSickLeavePay dailyRate days isFirst3Days
  | isFirst3Days = dailyRate * min (fromIntegral days) 3 * 0.6
  | otherwise = dailyRate * fromIntegral days * 0.8

-- ============================================================================
-- ADVANCE CALCULATIONS
-- ============================================================================

calcAdvanceAmount :: Double -> Double -> Double
calcAdvanceAmount salary percentage = salary * percentage / 100

calcMonthlyAdvance :: Double -> Double
calcMonthlyAdvance = flip calcAdvanceAmount 40 -- Default 40%

-- ============================================================================
-- FINAL SETTLEMENT
-- ============================================================================

calcFinalSettlement :: Double -> Double -> Double -> Double
calcFinalSettlement gross advances deductions =
  calcNetSalaryFromGross gross - advances - deductions

calcYearEndBonus :: Int -> Double -> Double
calcYearEndBonus monthsWorked monthlySalary
  | monthsWorked >= 12 = monthlySalary
  | monthsWorked >= 6 = monthlySalary * 0.5
  | monthsWorked >= 3 = monthlySalary * 0.25
  | otherwise = 0

-- ============================================================================
-- ATTENDANCE CALCULATIONS
-- ============================================================================

calcWorkedHours :: Double -> Double -> Double
calcWorkedHours total overtime = total + overtime * 1.5 -- 1.5x overtime rate

calcOvertimePay :: Double -> Double -> Double
calcOvertimePay hourlyRate overtime = hourlyRate * overtime * 1.5
