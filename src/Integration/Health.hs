{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DeriveAnyClass #-}

-- | Integration Health Monitoring
-- Phase 20-3: Health monitoring for external integrations
module Integration.Health
  ( HealthStatus(..)
  , IntegrationHealth(..)
  , recordSuccess
  , recordFailure
  , getHealthStatus
  , getUnhealthyIntegrations
  , checkHealthThreshold
  ) where

import Data.Text (Text)
import qualified Data.Text as T
import Data.Aeson (ToJSON, FromJSON)
import GHC.Generics (Generic)
import Data.Time (UTCTime)
import DAL.Database (Pool, usePool)
import DAL.Types (QueryResult(..))
import qualified Hasql.Session as Session
import Hasql.Statement (Statement(..))
import qualified Hasql.Decoders as D
import qualified Hasql.Encoders as E
import Data.Functor.Contravariant (contramap)

-- ============================================================================
-- HEALTH STATUS TYPES
-- ============================================================================

-- | Health status enumeration
data HealthStatus = Healthy | Degraded | Failed
  deriving (Show, Eq, Generic, ToJSON, FromJSON)

-- | Integration health record
data IntegrationHealth = IntegrationHealth
  { ihTenantId :: Text
  , ihAdapterType :: Text
  , ihStatus :: HealthStatus
  , ihFailureCount :: Int
  , ihLastSuccess :: Maybe UTCTime
  , ihLastFailure :: Maybe UTCTime
  , ihErrorMessage :: Maybe Text
  , ihLastChecked :: UTCTime
  } deriving (Show, Eq, Generic)

instance ToJSON IntegrationHealth
instance FromJSON IntegrationHealth

-- ============================================================================
-- HEALTH RECORDING FUNCTIONS
-- ============================================================================

-- | Record successful integration execution
recordSuccess :: Pool -> Text -> Text -> IO (QueryResult ())
recordSuccess pool tenantId adapterType = do
  let stmt = Statement
        "SELECT record_integration_success($1::UUID, $2::TEXT)"
        (contramap fst (E.param (E.nonNullable E.text)) <> contramap snd (E.param (E.nonNullable E.text)))
        D.noResult
        True
  res <- usePool pool $ Session.statement (tenantId, adapterType) stmt
  case res of
    Left err -> return $ QueryError (T.pack $ show err)
    Right () -> return $ QuerySuccess ()

-- | Record integration failure
recordFailure :: Pool -> Text -> Text -> Maybe Text -> IO (QueryResult ())
recordFailure pool tenantId adapterType errorMessage = do
  let stmt = Statement
        "SELECT record_integration_failure($1::UUID, $2::TEXT, $3::TEXT)"
        (contramap (\(a,_,_) -> a) (E.param (E.nonNullable E.text)) <>
         contramap (\(_,b,_) -> b) (E.param (E.nonNullable E.text)) <>
         contramap (\(_,_,c) -> c) (E.param (E.nullable E.text)))
        D.noResult
        True
  res <- usePool pool $ Session.statement (tenantId, adapterType, errorMessage) stmt
  case res of
    Left err -> return $ QueryError (T.pack $ show err)
    Right () -> return $ QuerySuccess ()

-- ============================================================================
-- HEALTH QUERY FUNCTIONS
-- ============================================================================

-- | Get health status for a specific adapter
getHealthStatus :: Pool -> Text -> Text -> IO (QueryResult IntegrationHealth)
getHealthStatus pool tenantId adapterType = do
  let stmt = Statement
        "SELECT adapter_type, status, failure_count, last_success, last_failure, error_message, last_checked \
        \FROM get_integration_health($1::UUID, $2::TEXT)"
        (contramap fst (E.param (E.nonNullable E.text)) <> contramap snd (E.param (E.nonNullable E.text)))
        (D.rowMaybe $ IntegrationHealth
          <$> pure tenantId
          <*> D.column (D.nonNullable D.text)
          <*> (parseStatus <$> D.column (D.nonNullable D.text))
          <*> (fromIntegral <$> D.column (D.nonNullable D.int4))
          <*> D.column (D.nullable D.timestamptz)
          <*> D.column (D.nullable D.timestamptz)
          <*> D.column (D.nullable D.text)
          <*> D.column (D.nonNullable D.timestamptz))
        True
  res <- usePool pool $ Session.statement (tenantId, adapterType) stmt
  case res of
    Left err -> return $ QueryError (T.pack $ show err)
    Right Nothing -> return $ QueryError "Health record not found"
    Right (Just health) -> return $ QuerySuccess health

-- | Get all unhealthy integrations for alerting
getUnhealthyIntegrations :: Pool -> Int -> IO (QueryResult [IntegrationHealth])
getUnhealthyIntegrations pool minFailureCount = do
  let stmt = Statement
        "SELECT tenant_id::TEXT, adapter_type, failure_count, status, last_failure, error_message, last_checked \
        \FROM get_unhealthy_integrations($1::INTEGER)"
        (E.param (E.nonNullable E.int4))
        (D.rowList $ IntegrationHealth
          <$> D.column (D.nonNullable D.text)
          <*> D.column (D.nonNullable D.text)
          <*> (parseStatus <$> D.column (D.nonNullable D.text))
          <*> (fromIntegral <$> D.column (D.nonNullable D.int4))
          <*> pure Nothing  -- last_success not returned by this function
          <*> D.column (D.nullable D.timestamptz)
          <*> D.column (D.nullable D.text)
          <*> D.column (D.nonNullable D.timestamptz))
        True
  res <- usePool pool $ Session.statement (fromIntegral minFailureCount) stmt
  case res of
    Left err -> return $ QueryError (T.pack $ show err)
    Right healthRecords -> return $ QuerySuccess healthRecords

-- | Check if health status exceeds threshold
checkHealthThreshold :: IntegrationHealth -> Int -> Bool
checkHealthThreshold health threshold =
  ihFailureCount health >= threshold &&
  ihStatus health `elem` [Degraded, Failed]

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

-- | Parse status string to HealthStatus
parseStatus :: Text -> HealthStatus
parseStatus "healthy" = Healthy
parseStatus "degraded" = Degraded
parseStatus "failed" = Failed
parseStatus _ = Degraded  -- Default to degraded for unknown status
