{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

module Domain.ReportSchedule
  ( ReportSchedule (..),
    ReportSnapshot (..),
    ReportScheduleInput (..),
    reportScheduleTemplates,
    validateReportSchedule,
  )
where

import Data.Aeson (FromJSON, ToJSON)
import Data.Int (Int64)
import qualified Data.Map as Map
import Data.Text (Text)
import qualified Data.Text as T
import Data.Time.Clock (UTCTime)
import Data.UUID (UUID)
import GHC.Generics (Generic)
import Surypus.Reports (ReportDef, allReports)

-- | Report schedule definition
data ReportSchedule = ReportSchedule
  { rsId :: Int64,
    rsName :: Text,
    rsReport :: Text,
    rsCron :: Text,
    rsEnabled :: Bool,
    rsParams :: Maybe Text,
    rsCreatedAt :: UTCTime,
    rsUpdatedAt :: UTCTime
  }
  deriving (Eq, Show, Generic, FromJSON, ToJSON)

-- | Report schedule input (for creating/updating)
data ReportScheduleInput = ReportScheduleInput
  { rsiName :: Text,
    rsiReport :: Text,
    rsiCron :: Text,
    rsiEnabled :: Bool,
    rsiParams :: Maybe Text
  }
  deriving (Eq, Show, Generic, FromJSON, ToJSON)

-- | Snapshot log entry
data ReportSnapshot = ReportSnapshot
  { rssId :: Int64,
    rssScheduleId :: Int64,
    rssRunId :: UUID,
    rssRunAt :: UTCTime,
    rssStatus :: Text,
    rssMessage :: Maybe Text,
    rssJrxml :: Maybe Text
  }
  deriving (Eq, Show, Generic, FromJSON, ToJSON)

-- | Available templates
reportScheduleTemplates :: [(Text, ReportDef)]
reportScheduleTemplates = Map.toList allReports

validateReportSchedule :: ReportScheduleInput -> Either Text ReportScheduleInput
validateReportSchedule input
  | T.null (T.strip (rsiName input)) = Left "name is required"
  | T.null (T.strip (rsiReport input)) = Left "report must be selected"
  | not (Map.member (rsiReport input) allReports) = Left "unknown report template"
  | T.null (T.strip (rsiCron input)) = Left "cron expression is required"
  | otherwise = Right input
