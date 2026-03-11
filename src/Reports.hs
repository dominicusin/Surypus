-- | Reports Module - Jasper/Pentaho integration
module Reports where

import           Data.Int  (Int64)
import           Data.Time (Day, fromGregorian)

-- | Report template
data ReportTemplate = ReportTemplate
  { rtId         :: Int64
  , rtCode       :: String
  , rtName       :: String
  , rtType       :: ReportType
  , rtJasperFile :: Maybe String
  } deriving (Show, Eq)

-- | Report types
data ReportType = RT_Sales | RT_Inventory | RT_Financial | RT_Tax | RT_Custom
  deriving (Show, Eq)

-- | Report parameters
data ReportParams = ReportParams
  { rpDateFrom :: Day
  , rpDateTo   :: Day
  } deriving (Show, Eq)

-- | Report status
data ReportStatus = RS_Pending | RS_Processing | RS_Completed | RS_Failed
  deriving (Show, Eq)

-- | Report job
data ReportJob = ReportJob
  { rjId         :: Int64
  , rjTemplateId :: Int64
  , rjStatus     :: ReportStatus
  , rjOutputPath :: Maybe String
  , rjCreatedAt  :: Day
  } deriving (Show, Eq)

-- | Available report templates
getReportTemplates :: [ReportTemplate]
getReportTemplates =
  [ ReportTemplate 1 "sales_daily" "Daily Sales" RT_Sales (Just "sales_daily.jrxml")
  , ReportTemplate 2 "inventory" "Inventory Report" RT_Inventory (Just "inventory.jrxml")
  , ReportTemplate 3 "balance_sheet" "Balance Sheet" RT_Financial (Just "balance_sheet.jrxml")
  ]

-- | Create report job
createReportJob :: Int64 -> ReportJob
createReportJob tid = ReportJob
  { rjId = 0
  , rjTemplateId = tid
  , rjStatus = RS_Pending
  , rjOutputPath = Nothing
  , rjCreatedAt = fromGregorian 2026 3 9
  }
