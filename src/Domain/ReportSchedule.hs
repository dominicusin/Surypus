{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

module Domain.ReportSchedule
  ( ReportSchedule(..)
  , ReportSnapshot(..)
  , ReportScheduleInput(..)
  , reportScheduleTemplates
  , validateReportSchedule
  ) where

import Data.Aeson (FromJSON, ToJSON, genericParseJSON, genericToJSON, defaultOptions)
import Data.Int (Int64)
import Data.Text (Text)
import Data.Time.Clock (UTCTime)
import Data.UUID (UUID)
import GHC.Generics (Generic)
import qualified Data.Text as T
import Surypus.Reports (ReportDef, allReports)
import qualified Data.Map as Map
import Data.Aeson.Types (Options(fieldLabelModifier))
import Data.List (isPrefixOf)

-- | Report schedule definition
data ReportSchedule = ReportSchedule
  { rsId       :: Maybe Int64
  , rsName     :: Text
  , rsReport   :: Text
  , rsCron     :: Text
  , rsParams   :: Maybe Text
  , rsEnabled  :: Bool
  , rsNextRun  :: Maybe UTCTime
  , rsCreated  :: Maybe UTCTime
  , rsUpdated  :: Maybe UTCTime
  } deriving (Eq, Show, Generic)

-- | Input for create/update
data ReportScheduleInput = ReportScheduleInput
  { rsiName    :: Text
  , rsiReport  :: Text
  , rsiCron    :: Text
  , rsiParams  :: Maybe Text
  , rsiEnabled :: Bool
  } deriving (Eq, Show, Generic)

-- | Snapshot log entry
data ReportSnapshot = ReportSnapshot
  { rssId          :: Int64
  , rssScheduleId  :: Int64
  , rssRunId       :: UUID
  , rssRunAt       :: UTCTime
  , rssStatus      :: Text
  , rssMessage     :: Maybe Text
  , rssJrxml       :: Maybe Text
  } deriving (Eq, Show, Generic)

instance FromJSON ReportSchedule where
  parseJSON = genericParseJSON (scheduleOptions "rs")

instance ToJSON ReportSchedule where
  toJSON = genericToJSON (scheduleOptions "rs")

instance FromJSON ReportScheduleInput where
  parseJSON = genericParseJSON (scheduleOptions "rsi")

instance ToJSON ReportScheduleInput where
  toJSON = genericToJSON (scheduleOptions "rsi")

instance FromJSON ReportSnapshot where
  parseJSON = genericParseJSON (scheduleOptions "rss")

instance ToJSON ReportSnapshot where
  toJSON = genericToJSON (scheduleOptions "rss")

scheduleOptions :: String -> Options
scheduleOptions prefix = defaultOptions { fieldLabelModifier = dropPrefix prefix }

dropPrefix :: String -> String -> String
dropPrefix prefix label
  | prefix `isPrefixOf` label = drop (length prefix) label
  | otherwise = label

-- | Available templates
reportScheduleTemplates :: [(Text, ReportDef)]
reportScheduleTemplates = Map.toList allReports

validateReportSchedule :: ReportScheduleInput -> Either Text ReportScheduleInput
validateReportSchedule input@ReportScheduleInput{..}
  | T.null (T.strip rsiName) = Left "name is required"
  | T.null (T.strip rsiReport) = Left "report must be selected"
  | not (Map.member rsiReport allReports) = Left "unknown report template"
  | T.null (T.strip rsiCron) = Left "cron expression is required"
  | otherwise = Right input
