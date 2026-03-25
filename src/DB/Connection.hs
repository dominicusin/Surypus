module DB.Connection
  ( PoolConfig (..),
    createPool,
    closePool,
    initSchema,
  )
where

import qualified Data.Text as T
import Data.Time.Clock (DiffTime, secondsToDiffTime)
import qualified Hasql.Connection.Settings as Settings
import qualified Hasql.Pool as Pool
import qualified Hasql.Pool.Config as PoolConfig

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

-- | Create a Hasql pool given the configuration
createPool :: PoolConfig -> IO Pool.Pool
createPool cfg = do
  let connSettings =
        Settings.hostAndPort (T.pack $ pcHost cfg) (fromIntegral $ pcPort cfg)
          <> Settings.user (T.pack $ pcUser cfg)
          <> Settings.password (T.pack $ pcPassword cfg)
          <> Settings.dbname (T.pack $ pcDatabase cfg)
  let poolConfig =
        PoolConfig.settings
          [ PoolConfig.size (pcConnections cfg),
            PoolConfig.staticConnectionSettings connSettings,
            PoolConfig.acquisitionTimeout (secondsToDiffTime 5) -- 5 second timeout
          ]
  Pool.acquire poolConfig

-- | Close the pool
closePool :: Pool.Pool -> IO ()
closePool = Pool.release

-- | Initialize database schema (no-op for now; migrations can be added later)
initSchema :: Pool.Pool -> IO ()
initSchema _pool = pure ()
