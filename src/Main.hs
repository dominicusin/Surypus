{-# LANGUAGE OverloadedStrings #-}

-- | Main entry point for Surypus API server
module Main where

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
import Data.Char (toLower)
import Data.Text (Text)
import qualified Data.Text as T
import Hasql.Pool (Pool)
import Surypus.API.Server (startServantServer)
import Surypus.APIShim.Server (startServantServerShim)
import Surypus.JWT (jwtConfigFromSecret)
import Surypus.RBAC.Store (newRBACStore)
import System.Environment (getArgs, lookupEnv)
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

    case parseServiceCommand args of
      Just cmd -> runServiceMode pool cmd
      Nothing -> do
        putStrLn "Starting Servant API server..."
        let jwtCfg = jwtConfigFromSecret "surypus-jwt-secret"
        rbacStore <- newRBACStore $ \_ -> pure ()
        useShim <- lookupEnv "USE_API_SHIM"
        let useShimFlag = maybe False (\s -> map toLower s `elem` ["true", "1", "yes"]) useShim
        if useShimFlag
          then startServantServerShim 3000 pool jwtCfg rbacStore
          else startServantServer 3000 pool jwtCfg rbacStore

runServiceMode :: Pool -> ServiceCommand -> IO ()
runServiceMode _ CmdHelp = putStrLn (T.unpack serviceCommandHelp)
runServiceMode pool cmd = case transition initialServiceState cmd of
  Left err -> hPutStrLn stderr (T.unpack err)
  Right state -> do
    putStrLn $ "Service phase: " <> show (serviceStatePhase state)
    case cmd of
      CmdRun -> do
        putStrLn "Starting API server..."
        let jwtCfg = jwtConfigFromSecret "surypus-jwt-secret"
        rbacStore <- newRBACStore $ \_ -> pure ()
        startServantServer 3000 pool jwtCfg rbacStore
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
