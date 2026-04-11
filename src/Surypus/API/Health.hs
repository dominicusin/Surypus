{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

-- | Health Check API
--
-- This module provides health check endpoints for monitoring the
-- application's status and dependencies.
--
-- = Overview
--
-- The health check API provides:
--
-- * Overall system status
-- * Database connectivity checks
-- * External service status (configurable)
--
-- = Usage
--
-- The health endpoint is typically called by:
--
-- * Load balancers for routing decisions
-- * Kubernetes liveness/readiness probes
-- * Monitoring systems for alerting
module Surypus.API.Health
  ( HealthStatus (..),
    HealthCheckResult (..),
    HealthCheckConfig (..),
    defaultHealthCheckConfig,
    checkDatabaseHealth,
    checkAllHealth,
  )
where

import Control.Exception (SomeException, try)
import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import Hasql.Pool (Pool)
import Surypus.Database.Pool (pingDatabasePool)

-- | Health status levels
data HealthStatus
  = StatusOK
  | StatusDegraded
  | StatusFailed
  deriving (Show, Eq)

-- | Result of a single health check
data HealthCheckResult = HealthCheckResult
  { hcName :: Text,
    hcStatus :: HealthStatus,
    hcMessage :: Maybe Text,
    hcLatencyUs :: Maybe Int64
  }
  deriving (Show, Eq)

-- | Configuration for health checks
data HealthCheckConfig = HealthCheckConfig
  { hccCheckDatabase :: Bool,
    hccDatabaseTimeoutSeconds :: Int
  }
  deriving (Show, Eq)

-- | Default health check configuration
defaultHealthCheckConfig :: HealthCheckConfig
defaultHealthCheckConfig =
  HealthCheckConfig
    { hccCheckDatabase = True,
      hccDatabaseTimeoutSeconds = 5
    }

-- | Check database connectivity
--
-- Returns 'HealthCheckResult' with database status
checkDatabaseHealth :: Pool -> IO HealthCheckResult
checkDatabaseHealth pool = do
  result <- try (pingDatabasePool pool) :: IO (Either SomeException Bool)
  case result of
    Right True ->
      pure $
        HealthCheckResult
          { hcName = "database",
            hcStatus = StatusOK,
            hcMessage = Just "Database connection successful",
            hcLatencyUs = Nothing
          }
    Right False ->
      pure $
        HealthCheckResult
          { hcName = "database",
            hcStatus = StatusFailed,
            hcMessage = Just "Database connection failed",
            hcLatencyUs = Nothing
          }
    Left (e :: SomeException) ->
      pure $
        HealthCheckResult
          { hcName = "database",
            hcStatus = StatusFailed,
            hcMessage = Just (T.pack (show e)),
            hcLatencyUs = Nothing
          }

-- | Run all health checks
--
-- Executes all configured health checks and returns a list of results
checkAllHealth :: Pool -> HealthCheckConfig -> IO [HealthCheckResult]
checkAllHealth pool cfg = do
  let checks = []
  dbCheck <-
    if hccCheckDatabase cfg
      then do
        result <- checkDatabaseHealth pool
        pure [result]
      else pure []
  pure (checks <> dbCheck)
