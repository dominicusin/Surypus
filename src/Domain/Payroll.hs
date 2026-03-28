{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards #-}

module Domain.Payroll
  ( PayrollSnapshotRequest (..),
    PayrollSnapshotPayload (..),
    PayrollSnapshotRecord (..),
    validatePayrollSnapshotRequest,
  )
where

import Data.Aeson (FromJSON, ToJSON)
import Data.Int (Int64)
import Data.Text (Text)
import Data.Time (Day, UTCTime, diffDays)
import Domain.HR (SalarySummary (..))
import GHC.Generics (Generic)

data PayrollSnapshotRequest = PayrollSnapshotRequest
  { psreqPeriodStart :: Day,
    psreqPeriodEnd :: Day
  }
  deriving (Eq, Show, Generic)

instance FromJSON PayrollSnapshotRequest

instance ToJSON PayrollSnapshotRequest

data PayrollSnapshotPayload = PayrollSnapshotPayload
  { pspPeriodStart :: Day,
    pspPeriodEnd :: Day
  }
  deriving (Eq, Show, Generic)

instance FromJSON PayrollSnapshotPayload

instance ToJSON PayrollSnapshotPayload

data PayrollSnapshotRecord = PayrollSnapshotRecord
  { psrId :: Int64,
    psrPeriodStart :: Day,
    psrPeriodEnd :: Day,
    psrCreatedAt :: UTCTime,
    psrSummary :: [SalarySummary]
  }
  deriving (Generic)

instance ToJSON PayrollSnapshotRecord

instance FromJSON PayrollSnapshotRecord

validatePayrollSnapshotRequest :: PayrollSnapshotRequest -> Either Text PayrollSnapshotRequest
validatePayrollSnapshotRequest req@PayrollSnapshotRequest {..}
  | psreqPeriodEnd < psreqPeriodStart = Left "period end must be after period start"
  | diffDays psreqPeriodEnd psreqPeriodStart > 366 = Left "snapshot range cannot exceed one year"
  | otherwise = Right req
