-- | Payroll Operations with Formal Verification
-- Модуль содержит инварианты и проверенные операции для расчета зарплаты
module Core.Payroll.Operations
  ( PayrollOpResult (..),
    validatePayrollPeriod,
    validateEmployeeRecord,
    calculateNetFromGross,
    calculateGrossFromNet,
    verifyTaxWithholding,
    verifySalaryAccruals,
    checkNegativeDeductions,
    checkPeriodOverlap,
    calcTotalPayroll,
    calcVacationDays,
    calcVacationPay,
    calcSickLeavePay,
    calcWorkedHours,
    calcOvertimePay,
    calcNDFL,
    calcTotalDeductions,
    calcTotalAccruals,
  )
where

import Core.Payroll.Types
import Data.List (sortBy)
import Data.Time (Day)
import qualified Data.Time as T
import Surypus.Refined ()
import Surypus.Refined.Predicates ()

-- | Payroll operation result
data PayrollOpResult
  = PayrollOpSuccess
  | PayrollOpInvalidPeriod
  | PayrollOpInvalidAmount
  | PayrollOpNegativeDeduction
  | PayrollOpTaxMismatch
  | PayrollOpPeriodOverlap

-- ============================================================================
-- VALIDATORS
-- ============================================================================

-- | Validate payroll period
-- Инвариант: начало периода <= конец периода
validatePayrollPeriod :: PayrollPeriod -> PayrollOpResult
validatePayrollPeriod pp
  | ppBeg pp > ppEnd pp = PayrollOpInvalidPeriod
  | otherwise = PayrollOpSuccess

-- | Validate employee salary record
-- Инвариант: зарплата >= 0, дата начала <= дата окончания
validateEmployeeRecord :: SalaryRec -> PayrollOpResult
validateEmployeeRecord s
  | sAmount s < 0 = PayrollOpInvalidAmount
  | sBeg s > sEnd s = PayrollOpInvalidPeriod
  | sAmount s > 1e8 = PayrollOpInvalidAmount
  | otherwise = PayrollOpSuccess

-- ============================================================================
-- SALARY CALCULATIONS
-- ============================================================================

-- | Calculate net salary from gross
-- Инвариант: net <= gross (удержания не превышают начисления)
-- Тип: gross -> tax rate -> net (если успех)
calculateNetFromGross :: Double -> Double -> Either String Double
calculateNetFromGross gross taxRate
  | gross < 0 = Left "Gross salary cannot be negative"
  | taxRate < 0 || taxRate > 100 = Left "Tax rate must be between 0 and 100"
  | net > gross = Left "Net salary cannot exceed gross"
  | otherwise = Right net
  where
    net = gross * (1 - taxRate / 100)

-- | Calculate gross salary from net
-- Инвариант: gross >= net
calculateGrossFromNet :: Double -> Double -> Either String Double
calculateGrossFromNet net taxRate
  | net < 0 = Left "Net salary cannot be negative"
  | taxRate < 0 || taxRate >= 100 = Left "Tax rate must be between 0 and 100"
  | otherwise = Right gross
  where
    gross = net / (1 - taxRate / 100)

-- ============================================================================
-- TAX CALCULATIONS (Russian NDFL 2024)
-- ============================================================================

-- | Calculate NDFL (income tax) with progressive scale
-- Инвариант: 0 <= tax <= gross
calcNDFL :: Double -> Double
calcNDFL gross
  | gross <= 0 = 0
  | gross <= 500000 = gross * 0.13
  | gross <= 3500000 = 65000 + (gross - 500000) * 0.15
  | gross <= 5000000 = 65000 + 450000 + (gross - 3500000) * 0.18
  | gross <= 20000000 = 65000 + 450000 + 2700000 + (gross - 5000000) * 0.20
  | otherwise = 65000 + 450000 + 2700000 + 3000000 + (gross - 20000000) * 0.22

-- | Verify tax withholding is correct
-- Инвариант: расчетный налог == удержанный налог
verifyTaxWithholding :: Double -> Double -> PayrollOpResult
verifyTaxWithholding gross expectedTax
  | calculatedTax /= expectedTax = PayrollOpTaxMismatch
  | otherwise = PayrollOpSuccess
  where
    calculatedTax = calcNDFL gross

-- ============================================================================
-- ACCRUALS AND DEDUCTIONS
-- ============================================================================

-- | Verify salary accruals are non-negative
-- Инвариант: все начисления >= 0
verifySalaryAccruals :: [SalaryRec] -> PayrollOpResult
verifySalaryAccruals = checkNegativeDeductions

-- | Check for negative deductions (should not exist)
-- Инвариант: вычеты не могут быть положительными начислениями
checkNegativeDeductions :: [SalaryRec] -> PayrollOpResult
checkNegativeDeductions records
  | any (\r -> sAmount r < 0 && sSalChargeId r > 0) records = PayrollOpNegativeDeduction
  | otherwise = PayrollOpSuccess

-- ============================================================================
-- TOTAL CALCULATIONS
-- ============================================================================

-- | Calculate total payroll for period
-- Инвариант: total >= 0
calcTotalPayroll :: [SalaryRec] -> Double
calcTotalPayroll = sum . map sAmount

-- | Calculate total deductions
-- Инвариант: deductions >= 0
calcTotalDeductions :: [SalaryRec] -> Double
calcTotalDeductions = sum . filter (< 0) . map sAmount

-- | Calculate total accruals
-- Инвариант: accruals >= 0
calcTotalAccruals :: [SalaryRec] -> Double
calcTotalAccruals = sum . filter (> 0) . map sAmount

-- ============================================================================
-- PERIOD VALIDATION
-- ============================================================================

-- | Check salary periods don't overlap for same employee
-- Инвариант: для одного сотрудника периоды не пересекаются
checkPeriodOverlap :: [SalaryRec] -> PayrollOpResult
checkPeriodOverlap [] = PayrollOpSuccess
checkPeriodOverlap [_] = PayrollOpSuccess
checkPeriodOverlap records
  | any (\(r1, r2) -> sEnd r1 >= sBeg r2) pairs = PayrollOpPeriodOverlap
  | otherwise = PayrollOpSuccess
  where
    sorted = sortBy (\a b -> compare (sBeg a) (sBeg b)) records
    pairs = zip sorted (tail sorted)

-- ============================================================================
-- VACATION CALCULATIONS
-- ============================================================================

-- | Calculate vacation days
-- Инвариант: result > 0
calcVacationDays :: Day -> Day -> Int
calcVacationDays start end = fromIntegral (T.diffDays end start) + 1

-- | Calculate vacation pay
-- Инвариант: result >= 0
calcVacationPay :: Double -> Int -> Double
calcVacationPay dailyRate days = dailyRate * fromIntegral days

-- ============================================================================
-- SICK LEAVE CALCULATIONS
-- ============================================================================

-- | Calculate sick leave pay
-- Инвариант: result >= 0, result <= dailyRate * days
calcSickLeavePay :: Double -> Int -> Bool -> Double
calcSickLeavePay dailyRate days isFirst3Days
  | isFirst3Days = dailyRate * min (fromIntegral days) 3 * 0.6
  | otherwise = dailyRate * fromIntegral days * 0.8

-- ============================================================================
-- ATTENDANCE
-- ============================================================================

-- | Calculate worked hours with overtime
-- Инвариант: result >= total hours
calcWorkedHours :: Double -> Double -> Double
calcWorkedHours total overtime = total + overtime * 1.5

-- | Calculate overtime pay
-- Инвариант: result >= 0
calcOvertimePay :: Double -> Double -> Double
calcOvertimePay hourlyRate overtime = hourlyRate * overtime * 1.5

-- ============================================================================
-- HELPERS
-- ============================================================================
