{-# LANGUAGE OverloadedStrings #-}
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

import Control.Exception (bracket)
import Data.Maybe (fromMaybe)
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

-- Placeholder pool type
data Pool = Pool String Int

-- | Create a pool (placeholder implementation)
createPool :: PoolConfig -> IO Pool
createPool _cfg = pure (Pool "mock" 10)

-- | Close the pool (no-op)
closePool :: Pool -> IO ()
closePool _ = pure ()

-- | Initialize database schema
initSchema :: Pool -> IO ()
initSchema _pool = pure ()

-- | Convenience wrapper
withPool :: (Pool -> IO a) -> IO a
withPool action = do
  cfg <- poolConfigFromEnv
  bracket (createPool cfg) closePool $ \pool -> action pool
