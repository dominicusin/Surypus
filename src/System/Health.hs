{-# LANGUAGE OverloadedStrings #-}

module System.Health
  ( AppHealth (..),
    HealthStatus (..),
    initHealthMonitor,
    checkDatabase,
    checkServices,
    checkQueue,
    runHealthChecks,
    getHealthStatus,
    SystemHealth (..),
    checkAllSystems,
  )
where

import Control.Concurrent.STM (TVar, atomically, newTVarIO, readTVar, writeTVar)
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import qualified Data.Text as T

data AppHealth = AppHealth
  { healthStatus :: TVar HealthStatus,
    healthChecks :: Map.Map Text (IO Bool),
    healthErrors :: TVar [Text]
  }

data HealthStatus
  = Healthy
  | Degraded
  | Critical
  deriving (Show, Eq)

initHealthMonitor :: IO AppHealth
initHealthMonitor = do
  status <- newTVarIO Healthy
  errors <- newTVarIO []
  let checks =
        Map.fromList
          [ ("database", checkDatabase),
            ("services", checkServices),
            ("queue", checkQueue)
          ]
  return $ AppHealth status checks errors

checkDatabase :: IO Bool
checkDatabase = return True

checkServices :: IO Bool
checkServices = return True

checkQueue :: IO Bool
checkQueue = return True

runHealthChecks :: AppHealth -> IO HealthStatus
runHealthChecks health = do
  results <- mapM (\(_, check) -> check) (Map.toList (healthChecks health))
  if all (== True) results
    then do
      atomically $ writeTVar (healthStatus health) Healthy
      return Healthy
    else do
      atomically $ writeTVar (healthStatus health) Degraded
      atomically $ writeTVar (healthErrors health) ["Some checks failed"]
      return Degraded

getHealthStatus :: AppHealth -> IO (HealthStatus, [Text])
getHealthStatus health = do
  status <- atomically $ readTVar (healthStatus health)
  errors <- atomically $ readTVar (healthErrors health)
  return (status, errors)

data SystemHealth = SystemHealth
  { systemHealthy :: Bool,
    systemMessage :: Text
  }

checkAllSystems :: IO SystemHealth
checkAllSystems = return $ SystemHealth True (T.pack "All systems operational")
