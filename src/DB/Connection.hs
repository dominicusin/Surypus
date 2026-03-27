module DB.Connection
  ( PoolConfig (..),
    defaultPoolConfig,
    poolConfigFromEnv,
    createPool,
    createPoolWithTimeout,
    closePool,
    initSchema,
  )
where

import qualified Data.Text as T
import Data.Time.Clock (secondsToDiffTime)
import qualified Hasql.Connection.Settings as Settings
import qualified Hasql.Pool as Pool
import qualified Hasql.Pool.Config as PoolConfig
import System.Environment (lookupEnv)
import Text.Read (readMaybe)

-- | Pool configuration for Hasql-based PostgreSQL connections
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
      pure (maybe fallback id value)

    getEnvOrDefaultRead :: (Read a) => String -> a -> IO a
    getEnvOrDefaultRead key fallback = do
      value <- lookupEnv key
      pure $ maybe fallback (maybe fallback id . readMaybe) value

-- | Create a Hasql pool given the configuration
createPool :: PoolConfig -> IO Pool.Pool
createPool cfg = createPoolWithTimeout cfg 5

createPoolWithTimeout :: PoolConfig -> Int -> IO Pool.Pool
createPoolWithTimeout cfg timeoutSeconds = do
  let connSettings =
        Settings.hostAndPort (T.pack $ pcHost cfg) (fromIntegral $ pcPort cfg)
          <> Settings.user (T.pack $ pcUser cfg)
          <> Settings.password (T.pack $ pcPassword cfg)
          <> Settings.dbname (T.pack $ pcDatabase cfg)
  let poolConfig =
        PoolConfig.settings
          [ PoolConfig.size (pcConnections cfg),
            PoolConfig.staticConnectionSettings connSettings,
            PoolConfig.acquisitionTimeout (secondsToDiffTime (fromIntegral (max 1 timeoutSeconds)))
          ]
  Pool.acquire poolConfig

-- | Close the pool
closePool :: Pool.Pool -> IO ()
closePool = Pool.release

-- | Initialize database schema (no-op for now; migrations can be added later)
initSchema :: Pool.Pool -> IO ()
initSchema _pool = pure ()
