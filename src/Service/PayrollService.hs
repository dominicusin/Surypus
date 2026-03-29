{-# LANGUAGE RecordWildCards #-}

module Service.PayrollService
  ( PayrollService (..),
    createPayrollService,
    calculateSalary,
    calculatePayroll,
    generatePayrollReport,
    processPayrollPayment,
  )
where

import Data.Int (Int64)
import Data.Text (Text)
import Data.Time (Day)
import Hasql.Pool (Pool)

data PayrollService = PayrollService
  {psPool :: Pool}

createPayrollService :: Pool -> PayrollService
createPayrollService = PayrollService

calculateSalary :: PayrollService -> Int64 -> Double -> Day -> Day -> IO (Either Text PayrollResult)
calculateSalary _ _ _ _ _ = pure $ Left "Not implemented"

calculatePayroll :: PayrollService -> [Employee] -> Day -> Day -> IO (Either Text [PayrollResult])
calculatePayroll _ _ _ _ = pure $ Left "Not implemented"

generatePayrollReport :: PayrollService -> Day -> Day -> IO (Either Text PayrollReport)
generatePayrollReport _ _ _ = pure $ Left "Not implemented"

processPayrollPayment :: PayrollService -> Int64 -> Double -> IO (Either Text Int64)
processPayrollPayment _ _ _ = pure $ Left "Not implemented"

data Employee = Employee
  { employeeId :: Int64,
    employeeName :: Text,
    employeeSalary :: Double
  }

data PayrollResult = PayrollResult
  { prEmployeeId :: Int64,
    prPeriodStart :: Day,
    prPeriodEnd :: Day,
    prGrossSalary :: Double,
    prNDFL :: Double,
    prNetSalary :: Double,
    prDaysWorked :: Double
  }

data PayrollReport = PayrollReport
  { payrollPeriodStart :: Day,
    payrollPeriodEnd :: Day,
    payrollEmployeeCount :: Int,
    payrollTotalGross :: Double,
    payrollTotalNDFL :: Double,
    payrollTotalNet :: Double,
    payrollDetails :: [PayrollResult]
  }
