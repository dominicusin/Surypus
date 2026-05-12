-- | Cached Read Model - In-memory TTL cache for account read models
-- US-3-3: Read models Redis cache (in-memory TTL implementation)
{-# LANGUAGE OverloadedStrings #-}
module Core.Accounting.Cache
  ( ReadModelCache
  , mkReadModelCache
  , getCachedAccountReadModel
  , getCachedBalance
  , invalidateCache
  , clearCache
  , cacheStats
  ) where

import Data.Int (Int64)
import Data.Text (Text)
import Data.Time (UTCTime, getCurrentTime, addUTCTime, NominalDiffTime)
import Data.IORef (IORef, newIORef, readIORef, atomicModifyIORef')
import System.Cache (CacheStats(..))

import qualified Core.Accounting.ReadModel as RM

-- | Cache TTL in seconds
cacheTTL :: Double
cacheTTL = 10

-- | Read model cache state
data CacheState = CacheState
  { csModels :: [(Int64, (UTCTime, RM.AccountReadModel))]
  , chHits :: Int
  , chMisses :: Int
  }

-- | Read model cache handle
newtype ReadModelCache = ReadModelCache (IORef CacheState)

-- | Create a new read model cache
mkReadModelCache :: IO ReadModelCache
mkReadModelCache = do
  ref <- newIORef CacheState
    { csModels = []
    , chHits = 0
    , chMisses = 0
    }
  pure $ ReadModelCache ref

-- | Get cached account read model (or compute and cache)
getCachedAccountReadModel :: ReadModelCache -> Int64 -> IO RM.AccountReadModel
getCachedAccountReadModel (ReadModelCache ref) accountId = do
  now <- getCurrentTime
  state <- readIORef ref
  case lookup accountId (csModels state) of
    Just (expiresAt, model) | expiresAt > now -> do
      atomicModifyIORef' ref $ \s ->
        (s { chHits = chHits s + 1 }, ())
      pure model
    _ -> do
      result <- RM.replayAccountEvents accountId
      case result of
        Left _ -> do
          atomicModifyIORef' ref $ \s ->
            (s { chMisses = chMisses s + 1 }, ())
          pure $ emptyModel accountId now
        Right model -> do
          let expiresAt = addUTCTime (realToFrac cacheTTL) now
          atomicModifyIORef' ref $ \s ->
            ( s
                { csModels = (accountId, (expiresAt, model)) : filter (\(k, _) -> k /= accountId) (csModels s)
                , chMisses = chMisses s + 1
                }
            , ()
            )
          pure model

-- | Get cached balance
getCachedBalance :: ReadModelCache -> Int64 -> IO Double
getCachedBalance cache accountId = do
  model <- getCachedAccountReadModel cache accountId
  pure $ RM.bsCurrentBalance (RM.armBalanceState model)

-- | Invalidate cache for a specific account
invalidateCache :: ReadModelCache -> Int64 -> IO ()
invalidateCache (ReadModelCache ref) accountId =
  atomicModifyIORef' ref $ \s ->
    ( s { csModels = filter (\(k, _) -> k /= accountId) (csModels s) }
    , ()
    )

-- | Clear all cached entries
clearCache :: ReadModelCache -> IO ()
clearCache (ReadModelCache ref) =
  atomicModifyIORef' ref $ \s ->
    ( s { csModels = [] }
    , ()
    )

-- | Get cache statistics
cacheStats :: ReadModelCache -> IO CacheStats
cacheStats (ReadModelCache ref) = do
  state <- readIORef ref
  pure CacheStats
    { csHits = fromIntegral (chHits state)
    , csMisses = fromIntegral (chMisses state)
    , csSize = fromIntegral (length (csModels state))
    }

-- | Create an empty read model
emptyModel :: Int64 -> UTCTime -> RM.AccountReadModel
emptyModel accountId now = RM.AccountReadModel
  { RM.armAccountId = accountId
  , RM.armCode = Nothing
  , RM.armName = Nothing
  , RM.armAccountType = Nothing
  , RM.armCurrencyId = Nothing
  , RM.armBalanceState = RM.BalanceState
      { RM.bsAccountId = accountId
      , RM.bsCurrentBalance = 0
      , RM.bsDebitTotal = 0
      , RM.bsCreditTotal = 0
      , RM.bsLastUpdated = now
      , RM.bsEventCount = 0
      }
  , RM.armCreatedAt = now
  , RM.armUpdatedAt = now
  }