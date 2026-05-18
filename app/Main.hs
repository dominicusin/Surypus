{-# LANGUAGE OverloadedStrings #-}

module Main where

import Control.Exception (bracket)
import Control.Monad.Trans.Except (runExceptT)
import qualified DAL.Repository.RBAC as RBACRepo
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.Encoding as TE
import Hasql.Pool (Pool)
import Network.Wai
import Network.Wai.Handler.Warp
import Network.Wai.Handler.WebSockets
import qualified Network.WebSockets as WS
import Surypus.API.AuthMiddleware (withAuthzResolverAdvanced)
import Surypus.API.Authorization (requiredPermissionForPathMethod)
import Surypus.API.MetricsMiddleware (MetricsMiddlewareConfig (..), withMetricsCollection)
import Surypus.API.Server
import Surypus.Database.Pool (createDatabasePool, databasePoolConfigFromEnv, pingDatabasePool, releaseDatabasePool, runMigrations)
import Surypus.JWT (jwtConfigFromSecret)
import Surypus.Metrics (initMetrics)
import Surypus.RBAC (Permission)
import Surypus.RBAC.Store (listGrants, listRoles, newRBACStore, writeAuditEntry)
import Surypus.WebSocket (WebSocketHandler, initWebSocketHandler, handleWebSocket)
import Text.Read (readMaybe)

websocketApp :: WebSocketHandler -> WS.ServerApp
websocketApp handler pending = do
  conn <- WS.acceptRequest pending
  handleWebSocket handler conn

isWsRequest :: Request -> Bool
isWsRequest req = rawPathInfo req == "/ws"

requiredPermissionFor :: Request -> Maybe Permission
requiredPermissionFor req = requiredPermissionForPathMethod (requestMethod req) (TE.decodeUtf8 (rawPathInfo req))

main :: IO ()
main = do
  putStrLn "========================================="
  putStrLn "  Surypus ERP/CRM v0.2.0 (Servant)"
  putStrLn "========================================="

  let jwtSecret = "surypus-secret-key-2024" :: Text
      jwtCfg = jwtConfigFromSecret jwtSecret
      port = 8080

  dbCfg <- databasePoolConfigFromEnv
  bracket (createDatabasePool dbCfg) releaseDatabasePool $ \pool -> do
    dbOk <- pingDatabasePool pool
    putStrLn $ "Database connectivity: " <> if dbOk then "ok" else "failed"
    if dbOk
      then runMigrations pool
      else pure ()

    rbacStore <- newRBACStore $ \entry -> putStrLn $ "RBAC audit: " <> show entry

    metrics <- initMetrics
    wsHandler <- initWebSocketHandler

    let authPublicPaths =
          [ "/api/v1/login",
            "/api/v1/refresh",
            "/api/v1/health",
            "/api/v1/metrics",
            "/swagger.json",
            "/ws"
          ]
        metricsCfg = MetricsMiddlewareConfig metrics authPublicPaths

    putStrLn $ "Starting Servant server on port " <> show port
    putStrLn "API available at: http://localhost:8080/api/v1"
    putStrLn "WebSocket: ws://localhost:8080/ws"

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

    let combinedApp :: Application
        combinedApp req respond
          | isWsRequest req = do
              websocketsOr WS.defaultConnectionOptions (websocketApp wsHandler) metricsApp req respond
          | otherwise = metricsApp req respond

    run port combinedApp

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
