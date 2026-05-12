module System.CircuitBreakerBulkheadAdvanced where

import Control.Concurrent (forkIO, threadDelay)
import Control.Concurrent.STM (TVar, atomically, newTVarIO, readTVar, writeTVar)
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import Data.Time.Clock (UTCTime, diffUTCTime, getCurrentTime)
import System.ClockSync (Clock (Monotonic), getTime)

-- | Advanced bulkhead with monitoring and dynamic scaling
data CircuitBreakerBulkheadAdvanced = CircuitBreakerBulkheadAdvanced
  { cbPoolConfig :: TVar PoolConfig,
    cbActiveMap :: TVar (Map.Map Int (UTCTime, Maybe Text)),
    cbMetrics :: TVar BulkheadMetrics,
    cbMonitorVar :: TVar MonitorState,
    cbScalingVar :: TVar ScalingState
  }

-- | Dynamic pool configuration
data PoolConfig = PoolConfig
  { minPoolSize :: Int,
    maxPoolSize :: Int,
    currentPoolSize :: TVar Int,
    scaleUpThreshold :: Double,
    scaleDownThreshold :: Double
  }

-- | Monitor state for health tracking
data MonitorState = MonitorState
  { healthCheckInterval :: NominalDiffTime,
    lastHealthCheck :: UTCTime,
    healthHistory :: [(UTCTime, Bool)]
  }

-- | Scaling state
data ScalingState
  = Stable
  | ScalingUp {scaleTarget :: Int}
  | ScalingDown {scaleTarget :: Int}
  deriving (Show, Eq)

-- | Bulkhead metrics with advanced tracking
data BulkheadMetrics = BulkheadMetrics
  { totalRequests :: Int,
    rejectedRequests :: Int,
    activeResources :: Int,
    maxActiveResources :: Int,
    resourceWaitTimes :: [Double],
    scalingEvents :: [(UTCTime, Text)],
    partitionMetrics :: Map.Map Text (Int, Int)
  }

-- | Initialize advanced bulkhead
initCircuitBreakerBulkheadAdvanced :: IO CircuitBreakerBulkheadAdvanced

initBreaker = do
  poolVar <- newTVarIO $ PoolConfig 10 100 (newTVarIO 10) 0.8 0.3
  activeVar <- newTVarIO Map.empty
  metricsVar <-
    newTVarIO
      BulkheadMetrics
        { totalRequests = 0,
          rejectedRequests = 0,
          activeResources = 0,
          maxActiveResources = 0,
          resourceWaitTimes = [],
          scalingEvents = [],
          partitionMetrics = Map.empty
        }
  monitorVar <-
    newTVarIO
      MonitorState
        { healthCheckInterval = 30,
          lastHealthCheck = =<< getCurrentTime,
          healthHistory = []
        }
  scalingVar <- newTVarIO Stable
  -- Start background monitor
  _ <- forkIO $ monitoringLoop monitorVar
  return $
    CircuitBreakerBulkheadAdvanced
      { cbPoolConfig = poolVar,
        cbActiveMap = activeVar,
        cbMetrics = metricsVar,
        cbMonitorVar = monitorVar,
        cbScalingVar = scalingVar
      }
  where
    monitoringLoop var = do
      threadDelay (30 * 1000000)
      -- Health check logic
      return ()

-- | Dynamic resource acquisition
acquireResourceAdvanced :: CircuitBreakerBulkheadAdvanced -> Text -> IO (Either Text Int)
acquireResourceAdvanced breaker partition = do
  now <- getCurrentTime
  poolCfg <- readTVarIO (cbPoolConfig breaker)
  activeMap <- readTVarIO (cbActiveMap breaker)
  metrics <- readTVarIO (cbMetrics breaker)

  let activeCount = Map.size activeMap
      currentPool = currentPoolSize poolCfg

  if activeCount >= currentPool
    then do
      -- Check scaling
      scalingState <- readTVarIO (cbScalingVar breaker)
      let scaledPool = case scalingState of
            ScalingUp target -> min (maxPoolSize poolCfg) target
            ScalingDown target -> max (minPoolSize poolCfg) target
            Stable -> currentPool

      if activeCount >= scaledPool
        then do
          -- Record rejection
          atomically $ do
            m <- readTVar (cbMetrics breaker)
            writeTVar
              (cbMetrics breaker)
              m
                { rejectedRequests = rejectedRequests m + 1,
                  partitionMetrics =
                    Map.insertWith
                      combineMetrics
                      partition
                      (0, 1)
                      (partitionMetrics metrics)
                }
          return $ Left "Bulkhead partition saturated"
        else do
          -- Scale up temporarily
          acquireWithScale breaker partition now activeMap
    else do
      acquireWithScale breaker partition now activeMap
  where
    combineMetrics (a1, r1) (a2, r2) = (a1 + a2, r1 + r2)

acquireWithScale :: CircuitBreakerBulkheadAdvanced -> Text -> UTCTime -> Map.Map Int (UTCTime, Maybe Text) -> IO (Either Text Int)
acquireWithScale breaker partition now activeMap = do
  atomically $ do
    poolVar <- readTVar (cbPoolConfig breaker >>= readTVar . currentPoolSize)
    activeVar <- readTVar (cbActiveMap breaker)
    let newId = Map.size activeVar + 1
        updated = Map.insert newId (now, Just partition) activeVar
    writeTVar (cbActiveMap breaker) updated

    metrics <- readTVar (cbMetrics breaker)
    writeTVar
      (cbMetrics breaker)
      metrics
        { totalRequests = totalRequests metrics + 1,
          activeResources = Map.size updated,
          maxActiveResources = max (Map.size updated) (maxActiveResources metrics),
          partitionMetrics =
            Map.insertWith
              combineMetrics
              partition
              (1, 0)
              (partitionMetrics metrics)
        }
  return $ Right (Map.size activeMap + 1)
  where
    combineMetrics (a1, r1) (a2, r2) = (a1 + a2, r1 + r2)

-- | Release with monitoring
releaseResourceAdvanced :: CircuitBreakerBulkheadAdvanced -> Int -> IO ()
releaseResourceAdvanced breaker resourceId = do
  now <- getCurrentTime
  atomically $ do
    active <- readTVar (cbActiveMap breaker)
    case Map.lookup resourceId active of
      Just (_, Just partition) -> do
        let updated = Map.delete resourceId active
        writeTVar (cbActiveMap breaker) updated
        m <- readTVar (cbMetrics breaker)
        writeTVar
          (cbMetrics breaker)
          m
            { activeResources = Map.size updated,
              partitionMetrics = Map.adjust (\(a, _) -> (max 0 (a - 1), 0)) partition (partitionMetrics m)
            }
      _ -> return ()

-- | Bulkhead partition management
data PartitionManager = PartitionManager
  { managerPartitions :: TVar [CircuitBreakerBulkheadAdvanced],
    managerStrategy :: PartitionStrategy
  }

data PartitionStrategy
  = WeightedRoundRobin
  | LeastConnections
  | PartitionLocal Text

-- | Execute with partition awareness
executeWithPartition :: PartitionManager -> Text -> IO a -> IO (Either Text a)
executeWithPartition manager partitionId action = do
  partitions <- readTVarIO (managerPartitions manager)
  case find (\p -> partitionId == cbServiceName (p :: CircuitBreakerBulkheadAdvanced)) partitions of
    Just partition -> executeWithBulkhead partition action
    Nothing -> return $ Left "Partition not found"

-- | Partition health monitoring
monitorPartitionHealth :: CircuitBreakerBulkheadAdvanced -> IO [(Text, Bool)]
monitorPartitionHealth breaker = do
   now <- getCurrentTime
   activeMap <- readTVarIO (cbActiveMap breaker)
   let health =
         map
           ( \(id, (timestamp, _)) ->
               ( cbServiceName breaker,
                 diffUTCTime now timestamp < 60 -- Active within 60s
               )
           )
           (Map.toList activeMap)
   return health
