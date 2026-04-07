{-# LANGUAGE OverloadedStrings #-}

-- | Database Connection Pool Management
--
-- This module provides compatibility with legacy code by re-exporting
-- from 'Surypus.Database.Pool'. New code should use 'Surypus.Database.Pool' directly.
module DB.Connection
  ( PoolConfig (..),
    defaultPoolConfig,
    poolConfigFromEnv,
    createPool,
    closePool,
    initSchema,
    withPool,
  )
where

import Data.Maybe (fromMaybe)
import Hasql.Pool (Pool)
import Surypus.Database.Pool
  ( DatabasePoolConfig (..),
    createDatabasePool,
    releaseDatabasePool,
  )
import System.Environment (lookupEnv)
import Text.Read (readMaybe)

data PoolConfig = PoolConfig
  { pcHost :: String,
    pcPort :: Int,
    pcUser :: String,
    pcPassword :: String,
    pcDatabase :: String,
    pcConnections :: Int
  }
  deriving (Eq, Show)

defaultPoolConfig :: PoolConfig
defaultPoolConfig =
  PoolConfig
    { pcHost = "localhost",
      pcPort = 5432,
      pcUser = "surypus",
      pcPassword = "surypus",
      pcDatabase = "surypus",
      pcConnections = 10
    }

poolConfigFromEnv :: IO PoolConfig
poolConfigFromEnv = do
  host <- getEnvOrDefault "DB_HOST" (pcHost defaultPoolConfig)
  port <- getEnvOrDefaultRead "DB_PORT" (pcPort defaultPoolConfig)
  user <- getEnvOrDefault "DB_USER" (pcUser defaultPoolConfig)
  password <- getEnvOrDefault "DB_PASSWORD" (pcPassword defaultPoolConfig)
  database <- getEnvOrDefault "DB_NAME" (pcDatabase defaultPoolConfig)
  connections <- getEnvOrDefaultRead "DB_POOL_SIZE" (pcConnections defaultPoolConfig)
  pure
    PoolConfig
      { pcHost = host,
        pcPort = port,
        pcUser = user,
        pcPassword = password,
        pcDatabase = database,
        pcConnections = max 1 connections
      }
  where
    getEnvOrDefault :: String -> String -> IO String
    getEnvOrDefault key fallback = do
      value <- lookupEnv key
      pure (fromMaybe fallback value)

    getEnvOrDefaultRead :: (Read a) => String -> a -> IO a
    getEnvOrDefaultRead key fallback = do
      value <- lookupEnv key
      pure $ maybe fallback (fromMaybe fallback . readMaybe) value

createPool :: PoolConfig -> IO Pool
createPool cfg =
  createDatabasePool
    DatabasePoolConfig
      { dpcHost = pcHost cfg,
        dpcPort = pcPort cfg,
        dpcUser = pcUser cfg,
        dpcPassword = pcPassword cfg,
        dpcDatabase = pcDatabase cfg,
        dpcPoolSize = pcConnections cfg
      }

closePool :: Pool -> IO ()
closePool = releaseDatabasePool

initSchema :: Pool -> IO ()
initSchema _pool = pure ()

withPool :: (Pool -> IO a) -> IO a
withPool action = do
  cfg <- poolConfigFromEnv
  createDatabasePool
    DatabasePoolConfig
      { dpcHost = pcHost cfg,
        dpcPort = pcPort cfg,
        dpcUser = pcUser cfg,
        dpcPassword = pcPassword cfg,
        dpcDatabase = pcDatabase cfg,
        dpcPoolSize = pcConnections cfg
      }
    >>= action
