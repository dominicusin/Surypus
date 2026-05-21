-- ============================================================================
-- SURYPUS ACCOUNTING REDIS CACHE
-- US-3-3: Read models Redis cache with TTL and Redis streams for events
-- Extends Core.Accounting.Cache with Redis backend
-- ============================================================================

{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE DeriveAnyClass #-}

module Core.Accounting.RedisCache
  ( -- * Redis Cache Types
    RedisCacheConfig  (..)
  , RedisAccountCache  (..)
  , RedisCacheResult  (..)

    -- * Redis Cache Operations
  , initializeRedisCache
  , getRedisCachedBalance
  , setRedisCachedBalance
  , getRedisAccountFromCache
  , setRedisAccountInCache
  , invalidateRedisAccountCache

    -- * Redis Streams for Events
  , publishAccountEventToStream
  , subscribeToAccountEventStream
  , processRedisEventStream

    -- * Integration with existing cache
  , wrapWithRedisBackend
  ) where

import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import Data.Time (UTCTime, NominalDiffTime, getCurrentTime, addUTCTime)
import Data.Aeson (ToJSON, FromJSON, encode, decode, Value)
import qualified Data.ByteString.Lazy as BL
import qualified Data.ByteString.Char8 as BS
import Data.String (IsString, fromString)
import GHC.Generics (Generic)
import Control.Monad.IO.Class (MonadIO, liftIO)
import Control.Exception (try, SomeException)
import qualified Data.Map.Strict as Map
import Data.Map.Strict (Map)

import Core.Accounting.Cache (ReadModelCache, getCachedAccountReadModel, invalidateCache)
import qualified Core.Accounting.ReadModel as RM

-- ============================================================================
-- REDIS CACHE TYPES
-- ============================================================================

-- | Redis cache configuration
data RedisCacheConfig = RedisCacheConfig
  { rccHost :: Text
  , rccPort :: Int
  , rccDatabase :: Int
  , rccDefaultTTL :: NominalDiffTime  -- 5-10 seconds as specified
  , rccEventStreamName :: Text
  , rccMaxConnections :: Int
  } deriving (Show, Eq, Generic)

-- | Redis cache result with metadata
data RedisCacheResult a = RedisCacheResult
  { rcrValue :: Maybe a
  , rcrFromRedis :: Bool  -- True if from Redis, False if fallback
  , rcrHit :: Bool
  , rcrTTL :: NominalDiffTime
  , rcrTimestamp :: UTCTime
  } deriving (Show, Eq, Generic)

-- | Redis account cache entry
data RedisAccountCache = RedisAccountCache
  { racAccountId :: Int64
  , racBalance :: Double
  , racDebitTotal :: Double
  , racCreditTotal :: Double
  , racLastUpdated :: UTCTime
  , racVersion :: Int64  -- Event version for consistency
  , racExpiresAt :: UTCTime
  } deriving (Show, Eq, Generic, ToJSON, FromJSON)

-- | Redis connection stub (replace with actual Redis client)
data RedisConnection = RedisConnection
  { rcConfig :: RedisCacheConfig
  , rcConnected :: Bool
  , rcConnectionId :: Text
  }

-- ============================================================================
-- REDIS CLIENT (STUB IMPLEMENTATION)
-- ============================================================================

-- | Connect to Redis
connectRedis :: RedisCacheConfig -> IO RedisConnection
connectRedis config = do
  -- Stub implementation using in-memory state
  connId <- T.pack . show <$> getCurrentTime
  return $ RedisConnection
    { rcConfig = config
    , rcConnected = True
    , rcConnectionId = connId
    }

-- | Disconnect from Redis
disconnectRedis :: RedisConnection -> IO ()
disconnectRedis conn = do
  putStrLn $ "Disconnecting from Redis: " <> rcConnectionId conn
  return ()

-- ============================================================================
-- REDIS CACHE OPERATIONS
-- ============================================================================

-- | Initialize Redis cache
initializeRedisCache :: RedisCacheConfig -> IO RedisConnection
initializeRedisCache config = do
  conn <- connectRedis config
  putStrLn $ "Redis cache initialized with TTL: " <> T.pack (show (rccDefaultTTL config))
  return conn

-- | Get cached balance from Redis
getRedisCachedBalance :: RedisConnection -> Int64 -> IO (RedisCacheResult Double)
getRedisCachedBalance conn accountId = do
  now <- getCurrentTime
  let key = "account:balance:" <> T.pack (show accountId)
  result <- try $ getFromRedis conn key
  case result of
    Left (_ :: SomeException) -> do
      -- Redis error, return miss
      pure $ RedisCacheResult Nothing False False 0 now
    Right Nothing -> do
      -- Cache miss
      pure $ RedisCacheResult Nothing False False 0 now
    Right (Just cached) -> do
      -- Cache hit
      pure $ RedisCacheResult (Just cached) True True (rccDefaultTTL (rcConfig conn)) now

-- | Set cached balance in Redis
setRedisCachedBalance :: RedisConnection -> Int64 -> Double -> IO ()
setRedisCachedBalance conn accountId balance = do
  let key = "account:balance:" <> T.pack (show accountId)
      ttl = rccDefaultTTL (rcConfig conn)
  setInRedisWithTTL conn key balance ttl

-- | Get full account from Redis cache
getRedisAccountFromCache :: RedisConnection -> Int64 -> IO (RedisCacheResult RedisAccountCache)
getRedisAccountFromCache conn accountId = do
  now <- getCurrentTime
  let key = "account:full:" <> T.pack (show accountId)
  result <- try $ getFromRedis conn key
  case result of
    Left (_ :: SomeException) -> do
      pure $ RedisCacheResult Nothing False False 0 now
    Right Nothing -> do
      pure $ RedisCacheResult Nothing False False 0 now
    Right (Just cached) -> do
      -- Check if expired
      if racExpiresAt cached > now
        then pure $ RedisCacheResult (Just cached) True True (rccDefaultTTL (rcConfig conn)) now
        else do
          -- Expired, delete and return miss
          deleteFromRedis conn key
          pure $ RedisCacheResult Nothing False False 0 now

-- | Set full account in Redis cache
setRedisAccountInCache :: RedisConnection -> RedisAccountCache -> IO ()
setRedisAccountInCache conn account = do
  let key = "account:full:" <> T.pack (show (racAccountId account))
      ttl = rccDefaultTTL (rcConfig conn)
      expiresAt = addUTCTime (rccDefaultTTL (rcConfig conn)) (racLastUpdated account)
      accountWithExpiry = account { racExpiresAt = expiresAt }
  setInRedisWithTTL conn key accountWithExpiry ttl
  -- Also cache balance separately for faster access
  setRedisCachedBalance conn (racAccountId account) (racBalance account)

-- | Invalidate Redis account cache
invalidateRedisAccountCache :: RedisConnection -> Int64 -> IO ()
invalidateRedisAccountCache conn accountId = do
  let balanceKey = "account:balance:" <> T.pack (show accountId)
      fullKey = "account:full:" <> T.pack (show accountId)
  deleteFromRedis conn balanceKey
  deleteFromRedis conn fullKey

-- ============================================================================
-- REDIS STREAMS FOR EVENTS
-- ============================================================================

-- | Publish account event to Redis stream
publishAccountEventToStream :: RedisConnection -> Int64 -> Value -> IO ()
publishAccountEventToStream conn accountId eventData = do
  let streamName = rccEventStreamName (rcConfig conn)
      eventId = "account:" <> T.pack (show accountId) <> ":" <> T.pack (show (getCurrentTime))
      eventDataStr = BS.unpack (BL.toStrict (encode eventData))
  publishToRedisStream conn streamName eventId eventDataStr

-- | Subscribe to account event stream
subscribeToAccountEventStream :: RedisConnection -> (Value -> IO ()) -> IO ()
subscribeToAccountEventStream conn handler = do
  let streamName = rccEventStreamName (rcConfig conn)
  subscribeToRedisStream conn streamName $ \eventDataStr -> do
    case decode (BL.fromStrict (BS.pack eventDataStr)) of
      Just event -> handler event
      Nothing -> putStrLn $ "Invalid event data: " <> T.pack eventDataStr

-- | Process Redis event stream and update cache
processRedisEventStream :: RedisConnection -> ReadModelCache -> IO ()
processRedisEventStream redisConn memoryCache = do
  subscribeToAccountEventStream redisConn $ \event -> do
    -- Parse event and update both Redis and memory cache
    putStrLn $ "Processing event from Redis stream: " <> T.pack (show event)
    -- Invalidate cache on any event (stub implementation)
    -- In production: Parse specific event types and update accordingly

-- ============================================================================
-- INTEGRATION WITH EXISTING CACHE
-- ============================================================================

-- | Wrap existing cache with Redis backend for hybrid approach
wrapWithRedisBackend :: ReadModelCache -> RedisConnection -> Int64 -> IO RM.AccountReadModel
wrapWithRedisBackend memoryCache redisConn accountId = do
  -- Try Redis first
  redisResult <- getRedisAccountFromCache redisConn accountId
  case rcrValue redisResult of
    Just redisAccount -> do
      -- Convert Redis cache to read model
      pure $ redisAccountToReadModel redisAccount
    Nothing -> do
      -- Fallback to memory cache
      model <- getCachedAccountReadModel memoryCache accountId
      -- Update Redis with the result
      let redisAccount = readModelToRedisAccount model
      setRedisAccountInCache redisConn redisAccount
      pure model

-- | Convert Redis account cache to read model
redisAccountToReadModel :: RedisAccountCache -> RM.AccountReadModel
redisAccountToReadModel redisAccount = RM.AccountReadModel
  { RM.armAccountId = racAccountId redisAccount
  , RM.armCode = Nothing
  , RM.armName = Nothing
  , RM.armAccountType = Nothing
  , RM.armCurrencyId = Nothing
  , RM.armBalanceState = RM.BalanceState
      { RM.bsAccountId = racAccountId redisAccount
      , RM.bsCurrentBalance = racBalance redisAccount
      , RM.bsDebitTotal = racDebitTotal redisAccount
      , RM.bsCreditTotal = racCreditTotal redisAccount
      , RM.bsLastUpdated = racLastUpdated redisAccount
      , RM.bsEventCount = fromIntegral (racVersion redisAccount)
      }
  , RM.armCreatedAt = racLastUpdated redisAccount
  , RM.armUpdatedAt = racLastUpdated redisAccount
  }

-- | Convert read model to Redis account cache
readModelToRedisAccount :: RM.AccountReadModel -> RedisAccountCache
readModelToRedisAccount model = do
  now <- getCurrentTime
  let balanceState = RM.armBalanceState model
      expiresAt = addUTCTime (realToFrac 10) now  -- 10 second TTL
  RedisAccountCache
    { racAccountId = RM.armAccountId model
    , racBalance = RM.bsCurrentBalance balanceState
    , racDebitTotal = RM.bsDebitTotal balanceState
    , racCreditTotal = RM.bsCreditTotal balanceState
    , racLastUpdated = RM.bsLastUpdated balanceState
    , racVersion = fromIntegral (RM.bsEventCount balanceState)
    , racExpiresAt = expiresAt
    }

-- ============================================================================
-- REDIS STUB IMPLEMENTATIONS
-- ============================================================================

-- | Get value from Redis (stub)
getFromRedis :: (FromJSON a) => RedisConnection -> Text -> IO (Maybe a)
getFromRedis conn key = do
  putStrLn $ "Redis GET: " <> key
  pure Nothing

-- | Set value in Redis with TTL (stub)
setInRedisWithTTL :: (ToJSON a) => RedisConnection -> Text -> a -> NominalDiffTime -> IO ()
setInRedisWithTTL conn key value ttl = do
  putStrLn $ "Redis SETEX: " <> key <> " TTL: " <> T.pack (show ttl)

-- | Delete key from Redis (stub)
deleteFromRedis :: RedisConnection -> Text -> IO ()
deleteFromRedis conn key = do
  putStrLn $ "Redis DEL: " <> key

-- | Publish to Redis stream (stub)
publishToRedisStream :: RedisConnection -> Text -> Text -> Text -> IO ()
publishToRedisStream conn streamName eventId data_ = do
  putStrLn $ "Redis XADD to " <> streamName <> ": " <> eventId <> " -> " <> T.pack data_

-- | Subscribe to Redis stream (stub)
subscribeToRedisStream :: RedisConnection -> Text -> (String -> IO ()) -> IO ()
subscribeToRedisStream conn streamName handler = do
  putStrLn $ "Redis XSUBSCRIBE to: " <> streamName
