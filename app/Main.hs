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
import Surypus.API.Server
import Surypus.Database.Pool (createDatabasePool, databasePoolConfigFromEnv, pingDatabasePool, releaseDatabasePool, runMigrations)
import Surypus.JWT (jwtConfigFromSecret)
import Surypus.RBAC (Permission)
import Surypus.RBAC.Store (listGrants, listRoles, newRBACStore, writeAuditEntry)
import Text.Read (readMaybe)

websocketApp :: WS.ServerApp
websocketApp pending = do
  conn <- WS.acceptRequest pending
  putStrLn "WebSocket client connected"
  WS.withPingThread conn 30 (return ()) $ do
    msg <- WS.receiveData conn
    putStrLn $ "WebSocket received: " <> show msg
    WS.sendTextData conn $ ("Echo: " :: Text) <> msg

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

    putStrLn $ "Starting Servant server on port " <> show port
    putStrLn "API available at: http://localhost:8080/api/v1"
    putStrLn "WebSocket: ws://localhost:8080/ws"

    let servantApp = apiServer pool jwtCfg rbacStore
        publicPaths =
          [ "/api/v1/login",
            "/api/v1/refresh",
            "/api/v1/health",
            "/api/v1/metrics",
            "/ws"
          ]
        securedApp =
          withAuthzResolverAdvanced
            jwtCfg
            publicPaths
            requiredPermissionFor
            (listRoles rbacStore)
            (listGrants rbacStore)
            (checkPermissionInDatabase pool)
            (writeAuditEntry rbacStore)
            servantApp

    let combinedApp :: Application
        combinedApp req respond
          | isWsRequest req = do
              putStrLn $ "WS path detected: " <> show (rawPathInfo req)
              websocketsOr WS.defaultConnectionOptions websocketApp securedApp req respond
          | otherwise = securedApp req respond

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
