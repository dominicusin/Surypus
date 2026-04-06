

module Service.PayrollService
  ( PayrollService (..),
    createPayrollService,
    calcSalary,
    calcPayroll,
    generatePayrollReport,
    processPayrollPayment,
    Employee (..),
    PayrollResult (..),
    PayrollReport (..),
  )
where

import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import Data.Time (Day)
import qualified Hasql.Decoders as D
import qualified Hasql.Encoders as E
import Hasql.Pool (Pool, use)
import qualified Hasql.Session as Session
import Hasql.Statement (Statement)

data PayrollService = PayrollService
  { psPool :: Pool
  }

createPayrollService :: Pool -> PayrollService
createPayrollService = PayrollService

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

calcNDFL :: Double -> Double
calcNDFL gross =
  let annualGross = gross * 12
      annualDeduction = 600000
      taxableAnnual = max 0 (annualGross - annualDeduction)
      taxRate = 0.13
   in taxableAnnual * taxRate / 12

calcSalary :: PayrollService -> Int64 -> Double -> Day -> Day -> IO (Either Text PayrollResult)
calcSalary service employeeId baseSalary periodStart periodEnd = do
  result <-
    use (psPool service) $
      Session.query
        selectEmployeeStmt
        employeeId
  case result of
    Left err -> pure $ Left (T.pack (show err))
    Right [] -> pure $ Left "Employee not found"
    Right [(empId, empName, empSalary, daysWorked)] ->
      let grossSalary = if baseSalary > 0 then baseSalary else empSalary
          ndfl = calcNDFL grossSalary
          netSalary = grossSalary - ndfl
       in pure $
            Right
              PayrollResult
                { prEmployeeId = empId,
                  prPeriodStart = periodStart,
                  prPeriodEnd = periodEnd,
                  prGrossSalary = grossSalary / 100.0,
                  prNDFL = ndfl / 100.0,
                  prNetSalary = netSalary / 100.0,
                  prDaysWorked = fromIntegral (daysWorked :: Int16) / 1.0
                }
    _ -> pure $ Left "Unexpected employee data"

calcPayroll :: PayrollService -> [Employee] -> Day -> Day -> IO (Either Text [PayrollResult])
calcPayroll service employees periodStart periodEnd = do
  results <- mapM (\emp -> calcSalary service (employeeId emp) (employeeSalary emp) periodStart periodEnd) employees
  case sequence results of
    Left err -> pure $ Left err
    Right payrollResults -> pure $ Right payrollResults

generatePayrollReport :: PayrollService -> Day -> Day -> IO (Either Text PayrollReport)
generatePayrollReport service periodStart periodEnd = do
  result <-
    use (psPool service) $
      Session.query
        selectPayrollReportStmt
        ( periodStart,
          periodEnd
        )
  case result of
    Left err -> pure $ Left (T.pack (show err))
    Right [] ->
      pure $
        Right
          PayrollReport
            { payrollPeriodStart = periodStart,
              payrollPeriodEnd = periodEnd,
              payrollEmployeeCount = 0,
              payrollTotalGross = 0,
              payrollTotalNDFL = 0,
              payrollTotalNet = 0,
              payrollDetails = []
            }
    Right [(empCount, totalGross, totalNdfL, totalNet)] -> do
      detailsResult <-
        use (psPool service) $
          Session.query
            selectPayrollDetailsStmt
            ( periodStart,
              periodEnd
            )
      let details = case detailsResult of
            Left _ -> []
            Right rows ->
              [ PayrollResult
                  { prEmployeeId = eId,
                    prPeriodStart = periodStart,
                    prPeriodEnd = periodEnd,
                    prGrossSalary = fromIntegral (gross :: Int64) / 100.0,
                    prNDFL = fromIntegral (ndfL :: Int64) / 100.0,
                    prNetSalary = fromIntegral (net :: Int64) / 100.0,
                    prDaysWorked = fromIntegral (days :: Int16) / 1.0
                  }
                | (eId, gross, ndfL, net, days) <- rows
              ]
      pure $
        Right
          PayrollReport
            { payrollPeriodStart = periodStart,
              payrollPeriodEnd = periodEnd,
              payrollEmployeeCount = empCount,
              payrollTotalGross = fromIntegral (totalGross :: Int64) / 100.0,
              payrollTotalNDFL = fromIntegral (totalNdfL :: Int64) / 100.0,
              payrollTotalNet = fromIntegral (totalNet :: Int64) / 100.0,
              payrollDetails = details
            }
    _ -> pure $ Left "Unexpected payroll data"

processPayrollPayment :: PayrollService -> Int64 -> Double -> IO (Either Text Int64)
processPayrollPayment service employeeId amount = do
  let amountCents = round (amount * 100)
  result <- use (psPool service) $ do
    Session.execute insertPayrollPaymentStmt (employeeId, amountCents)
    Session.query selectLastPayrollIdStmt () :: Session.Session (Session.Result Int64)
  pure $ case result of
    Left err -> Left (T.pack (show err))
    Right [paymentId] -> Right paymentId
    Right _ -> Left "Failed to get payment ID"

selectEmployeeStmt :: Statement Int64 (Int64, Text, Int64, Int16)
selectEmployeeStmt =
  Session.statement
    "SELECT id, name, salary, days_worked FROM employees WHERE id = $1"
    (E.param (E.nonNullable E.int8))
    ( D.rowList
        ( D.column (D.nonNullable D.int8),
          D.column (D.nonNullable D.text),
          D.column (D.nonNullable D.int8),
          D.column (D.nonNullable D.int2)
        )
    )

selectPayrollReportStmt :: Statement (Day, Day) (Int64, Int64, Int64, Int64)
selectPayrollReportStmt =
  Session.statement
    "SELECT COUNT(DISTINCT employee_id), \
    \ COALESCE(SUM(gross_amount), 0), \
    \ COALESCE(SUM(ndfl_amount), 0), \
    \ COALESCE(SUM(net_amount), 0) \
    \ FROM payroll WHERE period_start = $1 AND period_end = $2"
    ( (,)
        <$> E.param (E.nonNullable E.date)
        <*> E.param (E.nonNullable E.date)
    )
    ( D.rowList
        ( D.column (D.nonNullable D.int8),
          D.column (D.nonNullable D.int64),
          D.column (D.nonNullable D.int64),
          D.column (D.nonNullable D.int64)
        )
    )

selectPayrollDetailsStmt :: Statement (Day, Day) [(Int64, Int64, Int64, Int64, Int16)]
selectPayrollDetailsStmt =
  Session.statement
    "SELECT employee_id, gross_amount, ndfl_amount, net_amount, days_worked \
    \ FROM payroll WHERE period_start = $1 AND period_end = $2 ORDER BY employee_id"
    ( (,)
        <$> E.param (E.nonNullable E.date)
        <*> E.param (E.nonNullable E.date)
    )
    ( D.rowList
        ( D.column (D.nonNullable D.int8),
          D.column (D.nonNullable D.int64),
          D.column (D.nonNullable D.int64),
          D.column (D.nonNullable D.int64),
          D.column (D.nonNullable D.int2)
        )
    )

insertPayrollPaymentStmt :: Statement (Int64, Int64) Int64
insertPayrollPaymentStmt =
  Session.statement
    "INSERT INTO payroll_payments (employee_id, amount, payment_date) VALUES ($1, $2, CURRENT_DATE) RETURNING id"
    ( (,)
        <$> E.param (E.nonNullable E.int8)
        <*> E.param (E.nonNullable E.int8)
    )
    (D.singleRow (D.column (D.nonNullable D.int8)))

selectLastPayrollIdStmt :: Statement () Int64
selectLastPayrollIdStmt =
  Session.statement
    "SELECT currval('payroll_payments_id_seq')"
    Session.noParams
    (D.singleRow (D.column (D.nonNullable D.int8)))
