{-# LANGUAGE OverloadedStrings #-}

module App (mkApp) where

import Control.Monad.Trans.Except (runExceptT)
import qualified DAL.Repository.RBAC as RBACRepo
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.Encoding as TE
import Hasql.Pool (Pool)
import Network.Wai
import Surypus.API.AuthMiddleware (withAuthzResolverAdvanced)
import Surypus.API.Authorization (requiredPermissionForPathMethod)
import Surypus.API.MetricsMiddleware (MetricsMiddlewareConfig (..), withMetricsCollection)
import Surypus.API.Server (apiServer)
import Surypus.Database.Pool (createDatabasePool, databasePoolConfigFromEnv, runMigrations)
import Surypus.JWT (jwtConfigFromSecret)
import Surypus.Metrics (initMetrics)
import Surypus.RBAC (Permission)
import Surypus.RBAC.Store (listGrants, listRoles, newRBACStore, writeAuditEntry)
import Text.Read (readMaybe)

-- | Unified entry point for creating a test application instance
-- This mirrors the logic in app/Main.hs but returns an Application for testing.
mkApp :: IO Application
mkApp = do
  let jwtSecret = "surypus-test-secret-key-2024" :: Text
      jwtCfg = jwtConfigFromSecret jwtSecret

  dbCfg <- databasePoolConfigFromEnv
  pool <- createDatabasePool dbCfg
  runMigrations pool

  rbacStore <- newRBACStore $ \_ -> pure ()
  metrics <- initMetrics

  let authPublicPaths =
        [ "/api/v1/login",
          "/api/v1/refresh",
          "/api/v1/health",
          "/api/v1/metrics",
          "/swagger.json"
        ]
      metricsCfg = MetricsMiddlewareConfig metrics authPublicPaths

  let servantApp = apiServer pool jwtCfg rbacStore metrics
      securedApp =
        withAuthzResolverAdvanced
          jwtCfg
          authPublicPaths
          requiredPermissionFor
          (listRoles rbacStore)
          (listGrants rbacStore)
          (checkPermissionInDatabase pool)
          (writeAuditEntry rbacStore)
          servantApp
      metricsApp = withMetricsCollection metricsCfg securedApp

  return metricsApp

requiredPermissionFor :: Request -> Maybe Permission
requiredPermissionFor req = requiredPermissionForPathMethod (requestMethod req) (TE.decodeUtf8 (rawPathInfo req))

checkPermissionInDatabase :: Pool -> Text -> Permission -> Maybe Text -> IO Bool
checkPermissionInDatabase pool principal permission _mResource = do
  let repo = RBACRepo.mkRBACRepository pool
  case readMaybe (T.unpack principal) of
    Nothing -> pure False
    Just userId -> do
      result <- runExceptT $ RBACRepo.checkUserAppPermissionRepo repo userId permission
      pure $ case result of
        Right allowed -> allowed
        Left _ -> False
