{-# LANGUAGE OverloadedStrings #-}

module DB.Connection
  ( PoolConfig (..),
    createPool,
    closePool,
    initSchema,
  )
where

import qualified Data.ByteString.Char8 as BS
import qualified Data.Text as T
import Hasql.Connection (acquire, release)
import qualified Hasql.Connection.Settings as Settings
import Hasql.Pool (Pool, acquire, release, use)

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
createPool :: PoolConfig -> IO Pool
createPool cfg = do
  let connSettings =
        settings
          (BS.pack $ pcHost cfg)
          (fromIntegral $ pcPort cfg)
          (BS.pack $ pcUser cfg)
          (BS.pack $ pcPassword cfg)
          (BS.pack $ pcDatabase cfg)
  acquire (pcConnections cfg) connSettings

-- | Close the pool
closePool :: Pool -> IO ()
closePool = release

-- | Initialize database schema (no-op for now; migrations can be added later)
initSchema :: Pool -> IO ()
initSchema _pool = return ()
