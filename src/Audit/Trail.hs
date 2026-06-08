{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE OverloadedStrings #-}
module Audit.Trail where

import Data.Aeson (ToJSON, FromJSON)
import Data.Int (Int64)
import Data.Text (Text)
import Data.Time (UTCTime)
import GHC.Generics (Generic)

data AuditEntry = AuditEntry
  { aeId :: Maybe Int64
  , aeTimestamp :: UTCTime
  , aeUserId :: Int64
  , aeAction :: Text
  , aeResourceType :: Text
  , aeResourceId :: Int64
  , aeOldValues :: Maybe Text
  , aeNewValues :: Maybe Text
  , aeIpAddress :: Text
  } deriving (Eq, Show, Generic, ToJSON, FromJSON)
