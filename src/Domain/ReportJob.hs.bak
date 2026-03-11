{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

module Domain.ReportJob
  ( ReportRenderPayload(..)
  ) where

import Data.Aeson (FromJSON, ToJSON)
import Data.Int (Int64)
import GHC.Generics (Generic)

{-@ data ReportRenderPayload = ReportRenderPayload
  { rrpScheduleId :: Int64
  } @-}

data ReportRenderPayload = ReportRenderPayload
  { rrpScheduleId :: Int64
  } deriving (Eq, Show, Generic)

instance FromJSON ReportRenderPayload
instance ToJSON ReportRenderPayload
