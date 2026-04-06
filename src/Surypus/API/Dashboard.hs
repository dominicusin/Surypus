{-# LANGUAGE OverloadedStrings #-}

-- | Dashboard API
--
-- This module provides dashboard statistics and analytics endpoints
-- for the ERP system.
module Surypus.API.Dashboard
  ( DashboardStatsResponse (..),
    fetchDashboardStats,
    toDashboardResponse,
  )
where

import qualified DAL.Queries as Q
import qualified DAL.Types as T
import Data.Int (Int64)
import Data.Text (Text)
import Hasql.Pool (Pool)

data DashboardStatsResponse = DashboardStatsResponse
  { dsRevenueToday :: Int64,
    dsOrdersToday :: Int64,
    dsGoodsCount :: Int64,
    dsClientsCount :: Int64,
    dsTimestamp :: Text
  }
  deriving (Show, Eq)

fetchDashboardStats :: Pool -> IO (T.QueryResult T.DashboardStats)
fetchDashboardStats = Q.getDashboardStats

toDashboardResponse :: T.DashboardStats -> DashboardStatsResponse
toDashboardResponse stats =
  DashboardStatsResponse
    { dsRevenueToday = fromIntegral (T.dsRevenueToday stats),
      dsOrdersToday = fromIntegral (T.dsOrdersToday stats),
      dsGoodsCount = fromIntegral (T.dsGoodsCount stats),
      dsClientsCount = fromIntegral (T.dsClientsCount stats),
      dsTimestamp = "2024-01-01T00:00:00Z"
    }
