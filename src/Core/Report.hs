-- | Report module - Reporting engine
module Core.Report where

import           Data.Int  (Int64)
import           Data.Text (Text)

-- | Report - Report template
data Report = Report
  { rptId    :: Int64
  , rptCode  :: Text
  , rptName  :: Text
  , rptType  :: ReportType
  , rptQuery :: Text  -- SQL or formula
  , rptFlags :: Int
  } deriving (Show, Eq)

data ReportType = RT_List | RT_Register | RT_Journal | RT_Balance | RT_Tax
  deriving (Show, Eq)

-- | ReportParam - Report parameter
data ReportParam = ReportParam
  { rpId       :: Int64
  , rpReportId :: Int64
  , rpName     :: Text
  , rpType     :: ParamType
  , rpDefault  :: Maybe Text
  } deriving (Show, Eq)

data ParamType = PT_Date | PT_DateRange | PT_Int | PT_Text | PT_Object
  deriving (Show, Eq)

-- | ReportOutput - Generated report
data ReportOutput = ReportOutput
  { roId       :: Int64
  , roReportId :: Int64
  , roFormat   :: OutputFormat
  , roPath     :: Text
  , roSize     :: Int64
  } deriving (Show, Eq)

data OutputFormat = OF_PDF | OF_XLSX | OF_HTML | OF_CSV
  deriving (Show, Eq)
