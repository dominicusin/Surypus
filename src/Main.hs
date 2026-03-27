{-# LANGUAGE OverloadedStrings #-}

-- | Main entry point for Surypus API server
module Main where

import APIServer (RateLimitConfig (..), ServerConfig (..), defaultRateLimit, runServer)
import Core.Service
  ( ServiceCommand (..),
    initialServiceState,
    parseServiceCommand,
    serviceCommandHelp,
    serviceStatePhase,
    transition,
  )
import Core.ServiceManager (runDaemon)
import DB.Connection
  ( PoolConfig (..),
    closePool,
    createPool,
    defaultPoolConfig,
    initSchema,
    withPool,
  )
import Data.Text (Text)
import qualified Data.Text as T
import Hasql.Pool (Pool)
import System.Environment (getArgs)
import System.IO (hPutStrLn, stderr)

main :: IO ()
main = do
  args <- getArgs
  putStrLn "========================================="
  putStrLn "  Surypus - ERP/CRM System"
  putStrLn "  Version 0.1.0"
  putStrLn "========================================="
  withPool $ \pool -> do
    putStrLn "Initializing database schema..."
    initSchema pool

    rateLimit <- defaultRateLimit

    let serverCfg =
          ServerConfig
            { scHost = "0.0.0.0",
              scPort = 3000,
              scLogRequests = True,
              scJwtSecret = "surypus-secret-key",
              scRateLimit = rateLimit,
              scPool = pool,
              scWebSocketHub = Nothing
            }

    case parseServiceCommand args of
      Just cmd -> runServiceMode serverCfg pool cmd
      Nothing -> do
        putStrLn "Starting API server..."
        runServer serverCfg

runServiceMode :: ServerConfig -> Pool -> ServiceCommand -> IO ()
runServiceMode _ _ CmdHelp = putStrLn (T.unpack serviceCommandHelp)
runServiceMode serverCfg pool cmd = case transition initialServiceState cmd of
  Left err -> hPutStrLn stderr (T.unpack err)
  Right state -> do
    putStrLn $ "Service phase: " <> show (serviceStatePhase state)
    case cmd of
      CmdRun -> do
        putStrLn "Executing ppws run command"
        runServer serverCfg
      CmdInstall login pw -> do
        putStrLn $ "Installing service (login=" <> show login <> ", password=" <> show pw <> ")"
      CmdUninstall ->
        putStrLn "Uninstalling service"
      CmdStart ->
        putStrLn "Starting service daemon"
      CmdStop ->
        putStrLn "Stopping service daemon"
      CmdClient ->
        putStrLn "Running client utilities"
      CmdDaemon -> do
        putStrLn "Starting daemon jobs"
        runDaemon pool
      CmdRFID ->
        putStrLn "Running RFID processor"
      _ ->
        pure ()
