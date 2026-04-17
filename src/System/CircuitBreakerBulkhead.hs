module System.CircuitBreakerBulkhead where

import Control.Concurrent (newEmptyMVar, putMVar, takeMVar)
import Control.Concurrent.STM (TVar, atomically, newTVarIO, readTVar, writeTVar)
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import Data.Time.Clock (UTCTime, getCurrentTime)

-- | Bulkhead circuit breaker with resource isolation
data CircuitBreakerBulkhead = CircuitBreakerBulkhead
  { cbPoolSize :: Int,
    cbActiveSet :: TVar (Map.Map Int (UTCTime, Maybe Text)),
    cbMetrics :: TVar BulkheadMetrics,
    cbResourceSem :: TVar ()
  }

-- | Bulkhead metrics
data BulkheadMetrics = BulkheadMetrics
  { totalRequests :: Int,
    rejectedRequests :: Int,
    activeResources :: Int,
    maxActiveResources :: Int,
    resourceWaitTimes :: [Double]
  }

-- | Initialize bulkhead circuit breaker
initCircuitBreakerBulkhead :: Int -> IO CircuitBreakerBulkhead

initBreaker poolSize = do
  activeVar <- newTVarIO Map.empty
  metricsVar <-
    newTVarIO
      BulkheadMetrics
        { totalRequests = 0,
          rejectedRequests = 0,
          activeResources = 0,
          maxActiveResources = 0,
          resourceWaitTimes = []
        }
  semVar <- newTVarIO ()
  return $
    CircuitBreakerBulkhead
      { cbPoolSize = poolSize,
        cbActiveSet = activeVar,
        cbMetrics = metricsVar,
        cbResourceSem = semVar
      }

-- | Acquire resource from bulkhead
acquireResource :: CircuitBreakerBulkhead -> IO (Either Text Int)
acquireResource breaker = do
  -- Simple semaphore-based resource acquisition
  _ <- takeMVar (cbResourceSem breaker)
  now <- getCurrentTime
  atomically $ do
    active <- readTVar (cbActiveSet breaker)
    let activeCount = Map.size active
    if activeCount >= cbPoolSize breaker
      then do
        -- Reject request
        putMVar (cbResourceSem breaker) ()
        metrics <- readTVar (cbMetrics breaker)
        writeTVar
          (cbMetrics breaker)
          metrics
            { totalRequests = totalRequests metrics + 1,
              rejectedRequests = rejectedRequests metrics + 1
            }
        return $ Left "Bulkhead pool exhausted"
      else do
        -- Acquire resource
        let id = activeCount + 1
        writeTVar (cbActiveSet breaker) (Map.insert id (now, Nothing) active)
        metrics <- readTVar (cbMetrics breaker)
        writeTVar
          (cbMetrics breaker)
          metrics
            { totalRequests = totalRequests metrics + 1,
              activeResources = activeCount + 1,
              maxActiveResources = max (activeCount + 1) (maxActiveResources metrics)
            }
        return $ Right id

-- | Release resource back to bulkhead
releaseResource :: CircuitBreakerBulkhead -> Int -> IO ()
releaseResource breaker resourceId = do
  now <- getCurrentTime
  atomically $ do
    active <- readTVar (cbActiveSet breaker)
    let updated = Map.delete resourceId active
    writeTVar (cbActiveSet breaker) updated
  _ <- putMVar (cbResourceSem breaker) ()
  return ()

-- | Execute with resource isolation
executeWithBulkhead :: CircuitBreakerBulkhead -> IO a -> IO (Either Text a)
executeWithBulkhead breaker action = do
  mbResource <- acquireResource breaker
  case mbResource of
    Left err -> return $ Left err
    Right resourceId -> do
      result <- try action
      case result of
        Right val -> do
          releaseResource breaker resourceId
          return $ Right val
        Left err -> do
          releaseResource breaker resourceId
          return $ Left err

-- | Bulkhead partition isolation
data Partition = Partition
  { partitionId :: Text,
    partitionPoolSize :: Int
  }

-- | Multi-partition bulkhead
data MultiPartitionBulkhead = MultiPartitionBulkhead
  { partitions :: [CircuitBreakerBulkhead],
    totalCapacity :: Int
  }

-- | Execute in specific partition
executeInPartition :: MultiPartitionBulkhead -> Int -> IO a -> IO (Either Text a)
executeInPartition bulkhead partitionId action =
  if partitionId < length (partitions bulkhead)
    then executeWithBulkhead (partitions bulkhead !! partitionId) action
    else return $ Left "Invalid partition"
