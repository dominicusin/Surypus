{-# LANGUAGE OverloadedStrings #-}

-- | Sync API
--
-- This module provides data synchronization API functionality.
module Surypus.API.Sync
  ( SyncStatus (..),
    SyncResult (..),
    SyncRequest (..),
    getSyncStatus,
    startSync,
  )
where

import Data.Int (Int64)
import Data.Text (Text)
import Data.Time (UTCTime, getCurrentTime)

data SyncStatus = SyncStatusOK | SyncStatusError Text
  deriving (Show, Eq)

data SyncResult = SyncResult
  { srStatus :: SyncStatus,
    srUpdatedCount :: Int,
    srTimestamp :: UTCTime
  }
  deriving (Show, Eq)

data SyncRequest = SyncRequest
  { srEntityTypes :: [Text],
    srSince :: UTCTime
  }
  deriving (Show, Eq)

getSyncStatus :: IO SyncStatus
getSyncStatus = pure SyncStatusOK

startSync :: SyncRequest -> IO SyncResult
startSync _req = do
  now <- getCurrentTime
  pure $
    SyncResult
      { srStatus = SyncStatusOK,
        srUpdatedCount = 0,
        srTimestamp = now
      }
