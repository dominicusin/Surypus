

module Service.ReportService
  ( ReportService (..),
    createReportService,
    generateSalesReport,
    generateInventoryReport,
    generateFinancialReport,
    generatePayrollSummary,
    generateTaxReport,
    SalesReport (..),
    InventoryReport (..),
    FinancialReport (..),
    PayrollSummary (..),
    TaxReport (..),
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

data ReportService = ReportService
  { rsPool :: Pool
  }

createReportService :: Pool -> ReportService
createReportService = ReportService

data SalesReport = SalesReport
  { salesBillCount :: Int,
    salesTotalAmount :: Double,
    salesTotalTax :: Double
  }

data InventoryReport = InventoryReport
  { inventoryItemCount :: Int,
    inventoryTotalQuantity :: Double
  }

data FinancialReport = FinancialReport
  { financialTotalDebit :: Double,
    financialTotalCredit :: Double
  }

data PayrollSummary = PayrollSummary
  { summaryEmployeeCount :: Int,
    summaryTotalPaid :: Double
  }

data TaxReport = TaxReport
  { taxTotalVAT :: Double,
    taxCount :: Int
  }

generateSalesReport :: ReportService -> Day -> Day -> IO (Either Text SalesReport)
generateSalesReport service fromDate toDate = do
  result <-
    use (rsPool service) $
      Session.query
        selectSalesReportStmt
        ( fromDate,
          toDate
        )
  pure $ case result of
    Left err -> Left (T.pack (show err))
    Right [] -> Right (SalesReport 0 0 0)
    Right [(billCount, totalAmount, totalTax)] ->
      Right
        SalesReport
          { salesBillCount = fromIntegral (billCount :: Int64),
            salesTotalAmount = fromIntegral (totalAmount :: Int64) / 100.0,
            salesTotalTax = fromIntegral (totalTax :: Int64) / 100.0
          }
    _ -> Right (SalesReport 0 0 0)

generateInventoryReport :: ReportService -> Maybe Int64 -> IO (Either Text InventoryReport)
generateInventoryReport service mLocationId = do
  result <- case mLocationId of
    Just locId -> use (rsPool service) $ Session.query selectInventoryByLocationStmt locId
    Nothing -> use (rsPool service) $ Session.query selectInventoryTotalStmt ()
  pure $ case result of
    Left err -> Left (T.pack (show err))
    Right [] -> Right (InventoryReport 0 0)
    Right [(itemCount, totalQty)] ->
      Right
        InventoryReport
          { inventoryItemCount = fromIntegral (itemCount :: Int64),
            inventoryTotalQuantity = fromIntegral (totalQty :: Int64) / 10000.0
          }
    _ -> Right (InventoryReport 0 0)

generateFinancialReport :: ReportService -> Day -> Day -> IO (Either Text FinancialReport)
generateFinancialReport service fromDate toDate = do
  result <-
    use (rsPool service) $
      Session.query
        selectFinancialReportStmt
        ( fromDate,
          toDate
        )
  pure $ case result of
    Left err -> Left (T.pack (show err))
    Right [] -> Right (FinancialReport 0 0)
    Right [(totalDebit, totalCredit)] ->
      Right
        FinancialReport
          { financialTotalDebit = fromIntegral (totalDebit :: Int64) / 100.0,
            financialTotalCredit = fromIntegral (totalCredit :: Int64) / 100.0
          }
    _ -> Right (FinancialReport 0 0)

generatePayrollSummary :: ReportService -> Day -> Day -> IO (Either Text PayrollSummary)
generatePayrollSummary service fromDate toDate = do
  result <-
    use (rsPool service) $
      Session.query
        selectPayrollSummaryStmt
        ( fromDate,
          toDate
        )
  pure $ case result of
    Left err -> Left (T.pack (show err))
    Right [] -> Right (PayrollSummary 0 0)
    Right [(empCount, totalPaid)] ->
      Right
        PayrollSummary
          { summaryEmployeeCount = fromIntegral (empCount :: Int64),
            summaryTotalPaid = fromIntegral (totalPaid :: Int64) / 100.0
          }
    _ -> Right (PayrollSummary 0 0)

generateTaxReport :: ReportService -> Day -> Day -> IO (Either Text TaxReport)
generateTaxReport service fromDate toDate = do
  result <-
    use (rsPool service) $
      Session.query
        selectTaxReportStmt
        ( fromDate,
          toDate
        )
  pure $ case result of
    Left err -> Left (T.pack (show err))
    Right [] -> Right (TaxReport 0 0)
    Right [(totalVAT, taxCountInt)] ->
      Right
        TaxReport
          { taxTotalVAT = fromIntegral (totalVAT :: Int64) / 100.0,
            taxCount = fromIntegral (taxCountInt :: Int64)
          }
    _ -> Right (TaxReport 0 0)

selectSalesReportStmt :: Statement (Day, Day) (Int64, Int64, Int64)
selectSalesReportStmt =
  Session.statement
    "SELECT COUNT(*), COALESCE(SUM(total_sum), 0), COALESCE(SUM(tax_sum), 0) \
    \ FROM bills WHERE bill_date BETWEEN $1 AND $2"
    ( (,)
        <$> E.param (E.nonNullable E.date)
        <*> E.param (E.nonNullable E.date)
    )
    ( D.rowList
        ( D.column (D.nonNullable D.int8),
          D.column (D.nonNullable D.int8),
          D.column (D.nonNullable D.int8)
        )
    )

selectInventoryTotalStmt :: Statement () (Int64, Int64)
selectInventoryTotalStmt =
  Session.statement
    "SELECT COUNT(*), COALESCE(SUM(qty), 0) FROM stock WHERE qty > 0"
    Session.noParams
    ( D.rowList
        ( D.column (D.nonNullable D.int8),
          D.column (D.nonNullable D.int8)
        )
    )

selectInventoryByLocationStmt :: Statement Int64 (Int64, Int64)
selectInventoryByLocationStmt =
  Session.statement
    "SELECT COUNT(*), COALESCE(SUM(qty), 0) FROM stock WHERE location_id = $1 AND qty > 0"
    (E.param (E.nonNullable E.int8))
    ( D.rowList
        ( D.column (D.nonNullable D.int8),
          D.column (D.nonNullable D.int8)
        )
    )

selectFinancialReportStmt :: Statement (Day, Day) (Int64, Int64)
selectFinancialReportStmt =
  Session.statement
    "SELECT COALESCE(SUM(debit_amount), 0), COALESCE(SUM(credit_amount), 0) \
    \ FROM acc_turn WHERE turn_date BETWEEN $1 AND $2"
    ( (,)
        <$> E.param (E.nonNullable E.date)
        <*> E.param (E.nonNullable E.date)
    )
    ( D.rowList
        ( D.column (D.nonNullable D.int8),
          D.column (D.nonNullable D.int8)
        )
    )

selectPayrollSummaryStmt :: Statement (Day, Day) (Int64, Int64)
selectPayrollSummaryStmt =
  Session.statement
    "SELECT COUNT(DISTINCT employee_id), COALESCE(SUM(net_amount), 0) \
    \ FROM payroll WHERE period_start >= $1 AND period_end <= $2"
    ( (,)
        <$> E.param (E.nonNullable E.date)
        <*> E.param (E.nonNullable E.date)
    )
    ( D.rowList
        ( D.column (D.nonNullable D.int8),
          D.column (D.nonNullable D.int8)
        )
    )

selectTaxReportStmt :: Statement (Day, Day) (Int64, Int64)
selectTaxReportStmt =
  Session.statement
    "SELECT COALESCE(SUM(tax_amount), 0), COUNT(*) \
    \ FROM tax_entries WHERE entry_date BETWEEN $1 AND $2"
    ( (,)
        <$> E.param (E.nonNullable E.date)
        <*> E.param (E.nonNullable E.date)
    )
    ( D.rowList
        ( D.column (D.nonNullable D.int8),
          D.column (D.nonNullable D.int8)
        )
    )
