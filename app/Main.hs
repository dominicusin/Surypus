{-# LANGUAGE OverloadedStrings #-}

module Main where

import Data.Int (Int64)
import Data.Text (Text)
import Network.Wai.Handler.Warp (run)
import Network.Wai.Middleware.Gzip (gzip, def)
import Network.Wai.Middleware.RequestLogger (logStdoutDev)
import Surypus.API.Server (apiServer)
import Surypus.API.Logger (initLogger, LogLevel(Info))
import DAL.ORMPool (createPool)
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

-- | Permission check: verify userId has required permission
checkPermission :: Int64 -> Text -> IO Bool
checkPermission userId permText = do
  -- TODO: wire with real RBAC store. For now, allow all.
  pure True

main :: IO ()
main = do
  pool <- createPool
  logger <- initLogger Info
  app <- apiServer pool logger publicPaths checkPermission
  port <- fmap (maybe 8080 read) (lookupEnv "PORT")
  putStrLn $ "Starting Surypus server on http://0.0.0.0:" ++ show port
  hFlush stdout
  run port $ logStdoutDev $ gzip def app
