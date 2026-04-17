module System.Cache where

import Control.Concurrent.STM (TVar, atomically, newTVarIO, readTVar, writeTVar)
import qualified Data.Map.Strict as Map
import Data.Maybe (isJust)
import Data.Time.Clock (UTCTime, diffUTCTime, getCurrentTime)

-- | Cache entry with TTL
data CacheEntry a = CacheEntry
  { cacheValue :: a,
    cacheExpiry :: UTCTime,
    cacheMetadata :: Map.Map Text Text
  }

-- | Cache configuration
data CacheConfig = CacheConfig
  { cacheDefaultTTL :: Int,
    cacheMaxSize :: Int,
    cacheCleanupInterval :: Int
  }

-- | In-memory cache store
data CacheStore k a = CacheStore
  { cacheMap :: TVar (Map.Map k (CacheEntry a)),
    cacheStats :: TVar CacheStats,
    cacheConfig :: CacheConfig
  }

-- | Cache statistics
data CacheStats = CacheStats
  { hits :: Int,
    misses :: Int,
    evictions :: Int
  }

-- | Initialize cache
initCache :: CacheConfig -> IO (CacheStore k a)
initCache config = do
  store <- newTVarIO Map.empty
  stats <- newTVarIO CacheStats {hits = 0, misses = 0, evictions = 0}
  return $ CacheStore store stats config

-- | Insert into cache with TTL
cacheInsert :: (Ord k) => CacheStore k a -> k -> a -> Int -> IO ()
cacheInsert store key value ttlSeconds = do
  now <- getCurrentTime
  let expiry = addUTCTime (fromIntegral ttlSeconds) now
      entry = CacheEntry value expiry Map.empty
  atomically $ do
    m <- readTVar (cacheMap store)
    let m' = Map.insert key entry m
    writeTVar (cacheMap store) m'
    -- Cleanup if over capacity
    cleanupIfNecessary store

-- | Lookup in cache
cacheLookup :: (Ord k) => CacheStore k a -> k -> IO (Maybe a)
cacheLookup store key = do
  now <- getCurrentTime
  atomically $ do
    m <- readTVar (cacheMap store)
    case Map.lookup key m of
      Nothing -> do
        -- Update stats
        return Nothing
      Just entry ->
        if cacheExpiry entry > now
          then do
            -- Hit
            return $ Just (cacheValue entry)
          else do
            -- Expired - delete
            let m' = Map.delete key m
            writeTVar (cacheMap store) m'
            return Nothing

-- | Delete from cache
cacheDelete :: (Ord k) => CacheStore k a -> k -> IO ()
cacheDelete store key = atomically $ do
  m <- readTVar (cacheMap store)
  writeTVar (cacheMap store) (Map.delete key m)

-- | Clear cache
cacheClear :: (Ord k) => CacheStore k a -> IO ()
cacheClear store = atomically $ writeTVar (cacheMap store) Map.empty

-- | Get cache stats
cacheStats :: CacheStore k a -> IO CacheStats
cacheStats store = readTVarIO (cacheStats store)

-- | Cleanup expired entries and enforce size limit
cleanupIfNecessary :: (Ord k) => CacheStore k a -> IO ()
cleanupIfNecessary store = do
  now <- getCurrentTime
  atomically $ do
    m <- readTVar (cacheMap store)
    let valid = Map.filter (\e -> cacheExpiry e > now) m
    writeTVar (cacheMap store) valid

-- | Cache monad transformer (simplified)
newtype CacheT m a = CacheT {runCacheT :: m a}
  deriving (Functor, Applicative, Monad)

-- | With cache context
withCache :: CacheConfig -> (forall k a. (Ord k) => CacheStore k a -> IO r) -> IO r
withCache config action = do
  store <- initCache config
  action store
