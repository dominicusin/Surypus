{-# LANGUAGE OverloadedStrings #-}

module Main where

import Data.Maybe (fromMaybe)
import System.Environment (lookupEnv)
import DB.Connection (PoolConfig(..), createPool, closePool, initSchema)
import Surypus.JobRunner (runJobWorker)

main :: IO ()
main = do
  putStrLn "========================================="
  putStrLn "  Surypus Job Worker"
  putStrLn "========================================="
  let poolCfg = PoolConfig
        { pcHost = "localhost"
        , pcPort = 5432
        , pcUser = "surypus"
        , pcPassword = "surypus"
        , pcDatabase = "surypus"
        , pcConnections = 5
        , pcStripes = 1
        , pcIdleTime = 60
        }
      intervalSeconds =
        fromMaybe 30 $ do
          val <- lookupEnv "SURYPUS_JOB_INTERVAL"
          pure $ read val
  pool <- createPool poolCfg
  initSchema pool
  putStrLn $ "Job worker polling every " ++ show intervalSeconds ++ " seconds"
  runJobWorker pool intervalSeconds
  closePool pool
