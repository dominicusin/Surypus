{-# LANGUAGE OverloadedStrings #-}

-- | Database Connection Pool Management
--
-- This module provides connection pool management for PostgreSQL databases
-- using the hasql-pool library. It supports configuration via environment
-- variables and includes health check capabilities.
--
-- = Environment Variables
--
-- * @DB_HOST@ - Database host (default: \"127.0.0.1\")
-- * @DB_PORT@ - Database port (default: 5432)
-- * @DB_USER@ - Database user (default: \"surypus\")
-- * @DB_PASSWORD@ - Database password (default: \"surypus\")
-- * @DB_NAME@ - Database name (default: \"surypus\")
-- * @DB_POOL_SIZE@ - Pool size (default: 10)
module Surypus.Database.Pool
  ( DatabasePoolConfig (..),
    defaultDatabasePoolConfig,
    databasePoolConfigFromEnv,
    createDatabasePool,
    releaseDatabasePool,
    withDatabasePool,
    pingDatabasePool,
    validatePoolConnection,
    runMigrations,
  )
where

import Control.Exception (bracket)
import Data.List (sort)
import Data.Maybe (fromMaybe)
import Data.Text (Text)
import qualified Data.Text as T
import Data.Text.Encoding (encodeUtf8)
import qualified Data.Text.IO as TIO
import qualified Hasql.Connection.Setting as ConnSetting
import qualified Hasql.Connection.Setting.Connection as Conn
import Hasql.Pool (Pool, use)
import qualified Hasql.Pool as Pool
import qualified Hasql.Pool.Config as PoolConfig
import qualified Hasql.Session as Session
import System.Directory (doesDirectoryExist, listDirectory)
import System.Environment (lookupEnv)
import Text.Read (readMaybe)

-- | Configuration for database connection pool
--
-- This type holds all configuration parameters needed to create
-- a connection pool to a PostgreSQL database.
data DatabasePoolConfig = DatabasePoolConfig
  { dpcHost :: String,
    dpcPort :: Int,
    dpcUser :: String,
    dpcPassword :: String,
    dpcDatabase :: String,
    dpcPoolSize :: Int
  }
  deriving (Eq, Show)

-- | Default pool configuration
--
-- Defaults:
--
-- * Host: @127.0.0.1@
-- * Port: @5432@
-- * User: @surypus@
-- * Password: @surypus@
-- * Database: @surypus@
-- * Pool size: @10@
defaultDatabasePoolConfig :: DatabasePoolConfig
defaultDatabasePoolConfig =
  DatabasePoolConfig
    { dpcHost = "127.0.0.1",
      dpcPort = 5432,
      dpcUser = "surypus",
      dpcPassword = "surypus",
      dpcDatabase = "surypus",
      dpcPoolSize = 10
    }

-- | Read pool configuration from environment variables
--
-- The following environment variables are read:
--
-- * @DB_HOST@ - Database host
-- * @DB_PORT@ - Database port (parsed as 'Int')
-- * @DB_USER@ - Database user
-- * @DB_PASSWORD@ - Database password
-- * @DB_NAME@ - Database name
-- * @DB_POOL_SIZE@ - Pool size (parsed as 'Int', minimum 1)
--
-- If an environment variable is not set, the default value from
-- 'defaultDatabasePoolConfig' is used.
databasePoolConfigFromEnv :: IO DatabasePoolConfig
databasePoolConfigFromEnv = do
  host <- getEnvOrDefault "DB_HOST" (dpcHost defaultDatabasePoolConfig)
  port <- getEnvOrDefaultRead "DB_PORT" (dpcPort defaultDatabasePoolConfig)
  user <- getEnvOrDefault "DB_USER" (dpcUser defaultDatabasePoolConfig)
  password <- getEnvOrDefault "DB_PASSWORD" (dpcPassword defaultDatabasePoolConfig)
  database <- getEnvOrDefault "DB_NAME" (dpcDatabase defaultDatabasePoolConfig)
  poolSize <- getEnvOrDefaultRead "DB_POOL_SIZE" (dpcPoolSize defaultDatabasePoolConfig)
  pure
    DatabasePoolConfig
      { dpcHost = host,
        dpcPort = port,
        dpcUser = user,
        dpcPassword = password,
        dpcDatabase = database,
        dpcPoolSize = max 1 poolSize
      }
  where
    getEnvOrDefault key fallback = do
      value <- lookupEnv key
      pure (fromMaybe fallback value)

    getEnvOrDefaultRead key fallback = do
      value <- lookupEnv key
      pure $ maybe fallback (fromMaybe fallback . readMaybe) value

-- | Create a database connection pool
--
-- This function creates a new connection pool using the provided configuration.
-- The pool manages connections to a PostgreSQL database and is suitable for
-- use in production environments.
--
-- /Note:/ Remember to call 'releaseDatabasePool' to clean up resources
-- when the pool is no longer needed, or use 'withDatabasePool' instead.
createDatabasePool :: DatabasePoolConfig -> IO Pool
createDatabasePool cfg =
  let connStr =
        T.pack ("postgresql://" <> dpcUser cfg <> ":" <> dpcPassword cfg <> "@" <> dpcHost cfg <> ":" <> show (dpcPort cfg) <> "/" <> dpcDatabase cfg)
      connSettings =
        PoolConfig.dynamicConnectionSettings
          (pure [ConnSetting.connection (Conn.string connStr)])
      poolCfg =
        PoolConfig.settings
          [ PoolConfig.size (dpcPoolSize cfg),
            connSettings
          ]
   in Pool.acquire poolCfg

-- | Release (close) a database connection pool
--
-- This function properly closes all connections in the pool and releases
-- any associated resources. After calling this function, the pool should
-- not be used.
releaseDatabasePool :: Pool -> IO ()
releaseDatabasePool = Pool.release

-- | Execute an action with a database connection pool
--
-- This is a convenience function that creates a pool, runs the provided
-- action, and automatically releases the pool when the action completes
-- (including in case of exceptions).
--
-- Example:
--
-- @
-- main :: IO ()
-- main = withDatabasePool $ \\pool -> do
--   result <- pingDatabasePool pool
--   print result
-- @
withDatabasePool :: (Pool -> IO a) -> IO a
withDatabasePool action = do
  cfg <- databasePoolConfigFromEnv
  bracket (createDatabasePool cfg) releaseDatabasePool action

-- | Ping the database to check connectivity
--
-- Executes a simple @SELECT 1@ query to verify that the database
-- is accessible and responding. This can be used for health checks.
--
-- Returns 'True' if the query succeeds, 'False' otherwise.
pingDatabasePool :: Pool -> IO Bool
pingDatabasePool pool = do
  result <- use pool (Session.sql "SELECT 1")
  pure $ case result of
    Right () -> True
    Left _ -> False

-- | Validate a connection by checking database version
--
-- This function performs a more thorough validation than 'pingDatabasePool'
-- by querying the PostgreSQL version. It can detect issues like:
--
-- * Network connectivity problems
-- * Authentication failures
-- * Database not found
-- * Insufficient privileges
--
-- Returns 'True' if the version query succeeds, 'False' otherwise.
validatePoolConnection :: Pool -> IO Bool
validatePoolConnection pool = do
  result <- use pool (Session.sql "SELECT version()")
  pure $ case result of
    Right _ -> True
    Left _ -> False

-- | Run database migrations
--
-- This function looks for SQL migration files in the @sql/migrations@ directory
-- and executes them in alphabetical order. This allows for incremental database
-- schema updates.
--
-- Migration files should be named with a prefix that ensures correct ordering,
-- for example: @001_initial_schema.sql@, @002_add_users.sql@, etc.
--
-- If the @sql/migrations@ directory does not exist, this function does nothing.
runMigrations :: Pool -> IO ()
runMigrations pool = do
  let migrationsDir = "sql/migrations"
  exists <- doesDirectoryExist migrationsDir
  if not exists
    then pure ()
    else do
      files <- sort <$> listDirectory migrationsDir
      mapM_ (runMigrationFile pool migrationsDir) files

-- | Run a single migration file
runMigrationFile :: Pool -> FilePath -> FilePath -> IO ()
runMigrationFile pool dir fileName = do
  sqlText <- TIO.readFile (dir <> "/" <> fileName)
  _ <- use pool (Session.sql (encodeUtf8 sqlText))
  pure ()
