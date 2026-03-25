{-# LANGUAGE DataKinds #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE UndecidableInstances #-}

-- | Payroll Types - Salary calculations and HR
module Core.Payroll.Types where

import Data.Int (Int64)
import Data.Text (Text)
import Data.Time (Day, DiffTime)

-- ============================================================================
-- SALARY TYPES (from salary.cpp)
-- ============================================================================

-- | Salary record
data SalaryRec = SalaryRec
  { sId :: Int64,
    sPostId :: Int64,
    sSalChargeId :: Int64,
    sExtObjId :: Int64,
    sBeg :: Day,
    sEnd :: Day,
    sAmount :: Double,
    sFlags :: Int,
    sLinkBillId :: Int64,
    sGenBillId :: Int64,
    sRByGenBill :: Int64
  }
  deriving (Show, Eq)

-- | Salary charge type
data SalaryCharge = SalaryCharge
  { scId :: Int64,
    scName :: Text,
    scCode :: Text,
    scType :: SalaryChargeType,
    scTaxable :: Bool,
    scFlags :: Int
  }
  deriving (Show, Eq)

data SalaryChargeType = SCT_Fixed | SCT_Periodic | SCT_Accrual | SCT_Deduction
  deriving (Show, Eq)

-- | HR Position
data HRPosition = HRPosition
  { posId :: Int64,
    posName :: Text,
    posCode :: Text,
    posParentId :: Maybe Int64,
    posFlags :: Int
  }
  deriving (Show, Eq)

-- | Employee
data Employee = Employee
  { empId :: Int64,
    empPersonId :: Int64,
    empPostId :: Int64,
    empHireDate :: Day,
    empDismissDate :: Maybe Day,
    empStatus :: EmployeeStatus,
    empSalary :: Double,
    empTabNum :: Text
  }
  deriving (Show, Eq)

data EmployeeStatus = ES_Active | ES_Dismissed | ES_OnLeave | ES_Archived
  deriving (Show, Eq)

-- | Time sheet entry
data TimeSheetEntry = TimeSheetEntry
  { tsId :: Int64,
    tsEmployeeId :: Int64,
    tsDate :: Day,
    tsHours :: Double,
    tsWorkType :: Int,
    tsFlags :: Int
  }
  deriving (Show, Eq)

-- | Payroll period
data PayrollPeriod = PayrollPeriod
  { ppBeg :: Day,
    ppEnd :: Day,
    ppStatus :: PeriodStatus,
    ppClosedAt :: Maybe Day
  }
  deriving (Show, Eq)

data PeriodStatus = PS_Draft | PS_Open | PS_Closed | PS_Calculated
  deriving (Show, Eq)

-- ============================================================================
-- VALIDATORS
-- ============================================================================

-- | Validate salary record
validateSalaryRec :: SalaryRec -> Bool
validateSalaryRec s =
  sId s >= 0
    && sPostId s > 0
    && sPostId s < 0x00ffffff
    && sSalChargeId s > 0
    && sSalChargeId s < 0x00ffffff
    && sExtObjId s >= 0
    && sBeg s <= sEnd s
    && sAmount s >= 0
    && sAmount s < 1e8
    && sFlags s == 0
    && sLinkBillId s >= 0
    && sLinkBillId s < 0x00ffffff
    && sGenBillId s >= 0
    && sGenBillId s < 0x00ffffff
    && sRByGenBill s == 0

-- | Validate employee
validateEmployee :: Employee -> Bool
validateEmployee e =
  empId e > 0
    && empPersonId e > 0
    && empPostId e > 0
    && empSalary e >= 0
    && maybe True (\d -> empHireDate e /= d) (empDismissDate e)

-- ============================================================================
-- CALCULATIONS
-- ============================================================================

-- | Calculate net salary
calcNetSalary :: Double -> Double -> Double
calcNetSalary gross taxRate = gross * (1 - taxRate / 100)

-- | Calculate gross from net
calcGrossFromNet :: Double -> Double -> Double
calcGrossFromNet net taxRate = net / (1 - taxRate / 100)

-- | Calculate tax amount
calcTaxAmount :: Double -> Double -> Double
calcTaxAmount gross taxRate = gross * taxRate / 100

-- | Calculate period days
calcPeriodDays :: PayrollPeriod -> Int
calcPeriodDays pp = diffDays (ppEnd pp) (ppBeg pp) + 1

-- | Calculate average hours
calcAverageHours :: [TimeSheetEntry] -> Double
calcAverageHours entries
  | null entries = 0
  | otherwise = sum (fmap tsHours entries) / fromIntegral (length entries)

-- ============================================================================
-- INVARIANTS
-- ============================================================================

-- | Check salary periods don't overlap
salaryPeriodNoOverlap :: [SalaryRec] -> Bool
salaryPeriodNoOverlap [] = True
salaryPeriodNoOverlap [_] = True
salaryPeriodNoOverlap (s1 : s2 : rest) =
  sEnd s1 < sBeg s2 && salaryPeriodNoOverlap (s2 : rest)

-- | Total salary non-negative
totalSalaryNonNegative :: [SalaryRec] -> Double
totalSalaryNonNegative = sum . fmap sAmount

-- | Total deductions
totalDeductions :: [SalaryRec] -> Double
totalDeductions = sum . filter (< 0) . fmap sAmount

-- | Total accruals
totalAccruals :: [SalaryRec] -> Double
totalAccruals = sum . filter (> 0) . fmap sAmount

-- ============================================================================
-- HELPERS
-- ============================================================================

diffDays :: Day -> Day -> Int
diffDays a b = fromIntegral (fromEnum a - fromEnum b)
