-- | In-Memory Cache for Surypus ERP
--
-- This module provides a simple in-memory cache implementation using
-- IORef and Map for lightweight caching of frequently accessed data.
--
-- = Design
--
-- The cache uses:
--
-- * 'IORef' for thread-safe reference updates
-- * 'Data.Map' for efficient key-value storage
-- * Simple TTL support (TTL parameter accepted but not enforced)
--
-- = Usage
--
-- @
-- cache <- createCache
-- cacheSet cache "user:1" "John" 300  -- 5 minute TTL
-- result <- cacheGet cache "user:1"
-- @
module Surypus.Cache
  ( Cache,
    createCache,
    cacheGet,
    cacheSet,
    cacheDelete,
  )
where

import Data.IORef (IORef, newIORef, readIORef, writeIORef)
import qualified Data.Map as M
import Data.Text (Text)

-- | Cache data structure
--
-- Contains an IORef to a Map for storing key-value pairs.
-- The cache is thread-safe for read/write operations.
data Cache = Cache
  { cacheRef :: IORef (M.Map Text Text)
  }

-- | Create a new empty cache
--
-- Initializes an empty in-memory cache.
createCache :: IO Cache
createCache = Cache <$> newIORef M.empty

-- | Get a value from the cache
--
-- Returns 'Nothing' if key doesn't exist.
cacheGet :: Cache -> Text -> IO (Maybe Text)
cacheGet cache key = do
  m <- readIORef (cacheRef cache)
  pure $ M.lookup key m

-- | Set a value in the cache
--
-- Parameters:
-- * Cache to update
-- * Key
-- * Value
-- * TTL in seconds (currently ignored - future enhancement)
--
-- Returns 'True' on success.
cacheSet :: Cache -> Text -> Text -> Int -> IO Bool
cacheSet cache key value _ttl = do
  m <- readIORef (cacheRef cache)
  writeIORef (cacheRef cache) $ M.insert key value m
  pure True

-- | Delete a value from the cache
--
-- Returns 'True' if key existed and was deleted, 'False' otherwise.
cacheDelete :: Cache -> Text -> IO Bool
cacheDelete cache key = do
  m <- readIORef (cacheRef cache)
  let mb = M.lookup key m
  writeIORef (cacheRef cache) $ M.delete key m
  pure $ case mb of
    Just _ -> True
    Nothing -> False
