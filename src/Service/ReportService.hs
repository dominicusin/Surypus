{-# LANGUAGE RecordWildCards #-}

module Service.ReportService
  ( ReportService (..),
    createReportService,
    generateSalesReport,
    generateInventoryReport,
    generateFinancialReport,
    generatePayrollSummary,
    generateTaxReport,
  )
where

import Data.Int (Int64)
import Data.Text (Text)
import Data.Time (Day)
import Hasql.Pool (Pool)

data ReportService = ReportService
  {rsPool :: Pool}

createReportService :: Pool -> ReportService
createReportService = ReportService

generateSalesReport :: ReportService -> Day -> Day -> IO (Either Text SalesReport)
generateSalesReport _ _ _ = pure $ Left "Not implemented"

generateInventoryReport :: ReportService -> Maybe Int64 -> IO (Either Text InventoryReport)
generateInventoryReport _ _ = pure $ Left "Not implemented"

generateFinancialReport :: ReportService -> Day -> Day -> IO (Either Text FinancialReport)
generateFinancialReport _ _ _ = pure $ Left "Not implemented"

generatePayrollSummary :: ReportService -> Day -> Day -> IO (Either Text PayrollSummary)
generatePayrollSummary _ _ _ = pure $ Left "Not implemented"

generateTaxReport :: ReportService -> Day -> Day -> IO (Either Text TaxReport)
generateTaxReport _ _ _ = pure $ Left "Not implemented"

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
