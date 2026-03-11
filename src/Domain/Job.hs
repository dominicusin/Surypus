{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards #-}

{-@ LIQUID "--reflection" @-}

module Domain.Job
  ( JobStatus(..)
  , JobRecord(..)
  , JobRequest(..)
  , JobFilter(..)
  , jobStatusText
  , jobStatusFromText
  , validateJobRequest
  ) where

import Data.Aeson (FromJSON, ToJSON)
import Data.Int (Int64)
import Data.Text (Text)
import Data.Time.Clock (UTCTime)
import GHC.Generics (Generic)
import qualified Data.Text as T

{-@ type NonEmptyText = {v:Text | v /= ""} @-}
{-@ type PriorityLevel = {v:Int | v >= 1 && v <= 10} @-}

data JobStatus
  = JobPending
  | JobRunning
  | JobCompleted
  | JobFailed
  | JobCancelled
  deriving (Eq, Show, Generic)

instance ToJSON JobStatus
instance FromJSON JobStatus

data JobRecord = JobRecord
  { jobId :: Int64
  , jobCode :: Text
  , jobName :: Text
  , jobType :: Text
  , jobStatus :: JobStatus
  , jobPriority :: Int
  , jobData :: Maybe Text
  , jobScheduledAt :: Maybe UTCTime
  , jobCreatedAt :: UTCTime
  , jobStartedAt :: Maybe UTCTime
  , jobCompletedAt :: Maybe UTCTime
  , jobErrorMessage :: Maybe Text
  , jobDependencies :: [Int64]
  } deriving (Eq, Show, Generic)

instance ToJSON JobRecord
instance FromJSON JobRecord

{-@ data JobFilter = JobFilter
  { jfStatus :: Maybe JobStatus
  , jfType :: Maybe Text
  } @-}
data JobFilter = JobFilter
  { jfStatus :: Maybe JobStatus
  , jfType :: Maybe Text
  } deriving (Eq, Show, Generic)

instance ToJSON JobFilter
instance FromJSON JobFilter

{-@ data JobRequest = JobRequest
  { jrCode      :: NonEmptyText
  , jrName      :: NonEmptyText
  , jrType      :: NonEmptyText
  , jrPriority  :: PriorityLevel
  , jrPayload   :: Maybe Text
  , jrScheduled :: Maybe UTCTime
  } @-}
data JobRequest = JobRequest
  { jrCode :: Text
  , jrName :: Text
  , jrType :: Text
  , jrPriority :: Int
  , jrPayload :: Maybe Text
  , jrScheduled :: Maybe UTCTime
  } deriving (Eq, Show, Generic)

instance ToJSON JobRequest
instance FromJSON JobRequest

jobStatusText :: JobStatus -> Text
jobStatusText JobPending = "pending"
jobStatusText JobRunning = "running"
jobStatusText JobCompleted = "completed"
jobStatusText JobFailed = "failed"
jobStatusText JobCancelled = "cancelled"

jobStatusFromText :: Text -> JobStatus
jobStatusFromText txt =
  case T.toLower txt of
    "running" -> JobRunning
    "completed" -> JobCompleted
    "failed" -> JobFailed
    "cancelled" -> JobCancelled
    _ -> JobPending

validateJobRequest :: JobRequest -> Either Text JobRequest
validateJobRequest jr@JobRequest{..}
  | T.null (T.strip jrCode) = Left "job code must not be empty"
  | T.null (T.strip jrName) = Left "job name must not be empty"
  | T.null (T.strip jrType) = Left "job type must not be empty"
  | jrPriority < 1 || jrPriority > 10 = Left "priority must be between 1 and 10"
  | otherwise = Right jr
