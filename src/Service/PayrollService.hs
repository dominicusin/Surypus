-- | Payroll Service — orchestrates payroll calculations and reporting
-- Patch F: Real payroll logic through Core.Payroll.Calculation
{-# LANGUAGE OverloadedStrings #-}

{-@ type NonNegDouble = {v:Double | v >= 0} @-}
{-@ type PosDouble   = {v:Double | v > 0}  @-}
{-@ type Rate        = {v:Double | v >= 0 && v <= 100} @-}

module Service.PayrollService where

import Data.Int (Int64)
import Data.Time (Day, getCurrentTime, UTCTime)
import Core.Payroll.Calculation

-- | Payroll calculation request
data PayrollRequest = PayrollRequest
  { prEmployeeId :: Int64
  , prPeriod :: Day
  , prBaseSalary :: Double
  , prBonus :: Double
  , prDaysWorked :: Int
  , prVacationDays :: Int
  , prSickDays :: Int
  }

-- | Payroll calculation result
data PayrollResult = PayrollResult
  { prCalcEmployeeId :: Int64
  , prCalcPeriod :: Day
  , prGrossSalary :: Double
  , prIncomeTax :: Double
  , prSocialTax :: Double
  , prNetSalary :: Double
  , prAdvance :: Double
  , prBonusAmount :: Double
  , prVacationPay :: Double
  , prSickPay :: Double
  , prTotalToPay :: Double
  } deriving (Show, Eq)

{-@ calculatePayroll :: {v:PayrollRequest | prBaseSalary v >= 0} -> IO {v:PayrollResult | prNetSalary v >= 0} @-}
-- | Calculate full payroll for an employee
calculatePayroll :: PayrollRequest -> IO PayrollResult
calculatePayroll req = do
  let gross = prBaseSalary req
      incomeTax = calcIncomeTax gross
      socialTax = calcSocialTax gross
      netSalary = calcNetSalaryFromGross gross
      advance = calcMonthlyAdvance gross
      bonus = prBonus req
      vacationPay = calcVacationPay (prVacationDays req) gross
      sickPay = calcSickPay (prSickDays req) gross
      totalToPay = netSalary + bonus + vacationPay + sickPay
  pure PayrollResult
    { prCalcEmployeeId = prEmployeeId req
    , prCalcPeriod = prPeriod req
    , prGrossSalary = gross
    , prIncomeTax = incomeTax
    , prSocialTax = socialTax
    , prNetSalary = netSalary
    , prAdvance = advance
    , prBonusAmount = bonus
    , prVacationPay = vacationPay
    , prSickPay = sickPay
    , prTotalToPay = totalToPay
    }

{-@ calcVacationPay :: Int -> NonNegDouble -> NonNegDouble @-}
-- | Calculate vacation pay (avg daily * days * 1.0)
calcVacationPay :: Int -> Double -> Double
calcVacationPay days monthlySalary = (monthlySalary / 29.3) * fromIntegral days

{-@ calcSickPay :: Int -> NonNegDouble -> NonNegDouble @-}
-- | Calculate sick pay (avg daily * days * 0.6 employer portion)
calcSickPay :: Int -> Double -> Double
calcSickPay days monthlySalary
  | days <= 0 = 0
  | days <= 3 = (monthlySalary / 29.3) * 0.60 * fromIntegral days
  | otherwise = let emp = (monthlySalary / 29.3) * 0.60 * 3
                    soc = (monthlySalary / 29.3) * 0.80 * fromIntegral (days - 3)
                in emp + soc

{-@ calculateYearEndSummary :: [{v:PayrollResult | prTotalToPay v >= 0}] -> NonNegDouble @-}
-- | Calculate year-end payroll summary
calculateYearEndSummary :: [PayrollResult] -> Double
calculateYearEndSummary results =
  sum (map prTotalToPay results)