{-# LANGUAGE OverloadedStrings #-}

module Main where

import Data.Int (Int64)
import Data.Text (Text)
import Network.Wai.Handler.Warp (run)
import Network.Wai.Middleware.Gzip (gzip, def)
import Surypus.API.Server (apiServer)
import Surypus.API.Logger (initLogger, LogLevel(Info))
import Surypus.Metrics (initMetrics)
import Surypus.RBAC (parsePermissionText, setPermissionChecker, permissionToText)
import DAL.Database (createPool)
import qualified DAL.Repository.RBAC as RBAC
import System.Environment (lookupEnv)
import System.IO (hFlush, stdout)

-- | Default public paths (no auth required)
publicPaths :: [Text]
publicPaths =
  [ "/api/v1/login",
    "/api/v1/refresh",
    "/api/v1/health",
    "/api/v1/metrics",
    "/swagger.json"
  ]

-- | Permission check: verify userId has required permission via RBAC repository
checkPermission :: RBAC.RBACRepository -> Int64 -> Text -> IO Bool
checkPermission repo userId permText =
  case parsePermissionText permText of
    Nothing -> pure False
    Just perm -> RBAC.checkUserAppPermissionRepo repo userId perm

main :: IO ()
main = do
  pool <- createPool
  let repo = RBAC.mkRBACRepository pool
      checkPerm = checkPermission repo
      rbacChecker userId perm = do
        hasPerm <- RBAC.checkUserAppPermissionRepo repo userId perm
        if hasPerm
          then pure $ Right ()
          else pure $ Left $ "Permission denied: " <> permissionToText perm
  setPermissionChecker rbacChecker
  logger <- initLogger Info
  metrics <- initMetrics
  app <- apiServer pool logger metrics publicPaths checkPerm
  port <- fmap (maybe 8080 read) (lookupEnv "PORT")
  putStrLn $ "Starting Surypus server on http://0.0.0.0:" ++ show port
  hFlush stdout
  run port $ gzip def app
