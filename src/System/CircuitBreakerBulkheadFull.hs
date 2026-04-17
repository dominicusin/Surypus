module System.CircuitBreakerBulkheadFull where

import Control.Concurrent.STM (TVar, newTVarIO, readTVar, writeTVar, atomically)
import Control.Concurrent (forkIO)
import Data.Time.Clock (UTCTime, getCurrentTime, diffUTCTime)
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import System.Clock (getTime, Clock(Monotonic))

-- | Full bulkhead with resource isolation, monitoring, and auto-scaling
data CircuitBreakerBulkheadFull = CircuitBreakerBulkheadFull
  { cbConfig :: TVar BulkheadConfig,
    cbResources :: TVar (Map.Map Int ResourceState),
    cbMetrics :: TVar BulkheadMetrics,
    cbMonitor :: TVar MonitorState,
    cbAutoScaler :: TVar AutoScaler
  }

-- | Bulkhead configuration with dynamic scaling
data BulkheadConfig = BulkheadConfig
  { minResources :: Int,
    maxResources :: Int,
    resourceCapacity :: TVar Int,
    loadThreshold :: Double,
    scaleCheckInterval :: Int
  }

-- | Resource state with health tracking
data ResourceState
  = ResourceActive { lastUsed :: UTCTime, usageCount :: Int }
  | ResourceIdle { idleSince :: UTCTime }
  | ResourceFailed { failureCount :: Int, lastFailure :: UTCTime }
  deriving (Show, Eq)

-- | Monitor state for health and performance
data MonitorState = MonitorState
  { checkInterval :: NominalDiffTime,
    lastCheck :: UTCTime,
    healthLog :: [(UTCTime, Text, Bool)]
  }

-- | Auto-scaling state
data AutoScaler
  | StableState
  | ScalingUp { targetResources :: Int }
  | ScalingDown { targetResources :: Int }
  deriving (Show, Eq)

-- | Comprehensive bulkhead metrics
data BulkheadMetrics = BulkheadMetrics
  { totalRequests :: Int,
    rejectedRequests :: Int,
    activeResources :: Int,
    idleResources :: Int,
    failedResources :: Int,
    avgWaitTime :: Double,
    maxWaitTime :: Double,
    scalingEvents :: [(UTCTime, Text, Int, Int)]
  }

-- | Initialize full bulkhead circuit breaker
initCircuitBreakerBulkheadFull :: IO CircuitBreakerBulkheadFull
initBreaker = do
  configVar <- newTVarIO $ BulkheadConfig
    { minResources = 5,
      maxResources = 100,
      resourceCapacity = newTVarIO 10,
      loadThreshold = 0.8,
      scaleCheckInterval = 60
    }
  resourcesVar <- newTVarIO Map.empty
  metricsVar <- newTVarIO BulkheadMetrics
    { totalRequests = 0,
      rejectedRequests = 0,
      activeResources = 0,
      idleResources = 0,
      failedResources = 0,
      avgWaitTime = 0,
      maxWaitTime = 0,
      scalingEvents = []
    }
  monitorVar <- newTVarIO MonitorState
    { checkInterval = 30,
      lastCheck = =<< getCurrentTime,
      healthLog = []
    }
  scalerVar <- newTVarIO StableState
  -- Start monitoring thread
  _ <- forkIO $ monitoringThread monitorVar scalerVar configVar resourcesVar
  return $ CircuitBreakerBulkheadFull
    { cbConfig = configVar,
      cbResources = resourcesVar,
      cbMetrics = metricsVar,
      cbMonitor = monitorVar,
      cbAutoScaler = scalerVar
    }

-- | Monitoring thread for health and scaling
monitoringThread :: TVar MonitorState -> TVar AutoScaler -> TVar BulkheadConfig -> TVar (Map.Map Int ResourceState) -> IO ()
monitoringThread monitorVar scalerVar configVar resourcesVar = do
  threadDelay (60 * 1000000)  -- 1 minute interval
  now <- getCurrentTime
  -- Health check all resources
  resources <- readTVarIO resourcesVar
  let (healthy, unhealthy) = partition (\(_, state) -> 
        case state of
          ResourceActive _ _ -> True
          ResourceIdle _ -> True
          ResourceFailed _ _ -> False) (Map.toList resources)
  
  -- Update monitor state
  atomically $ do
    writeTVar monitorVar MonitorState
      { checkInterval = checkInterval monitorVar,
        lastCheck = now,
        healthLog = (now, "health_check", null unhealthy) : healthLog monitorVar
      }
  
  -- Auto-scaling logic
  when (not (null unhealthy)) $ do
    config <- readTVarIO configVar
    currentResources <- readTVarIO resourcesVar
    let load = fromIntegral (Map.size currentResources) / fromIntegral (fromIntegral (maxResources (config)))
    scaler <- readTVarIO scalerVar
    case scaler of
      StableState -> when (load > loadThreshold config) $
        adjustScale scalerVar (ScalingUp (max (minResources (config)) (Map.size currentResources + 1)))
      ScalingUp target -> when (Map.size currentResources >= target) $
        adjustScale scalerVar StableState
      ScalingDown target -> when (Map.size currentResources <= target) $
        adjustScale scalerVar StableState
  
  -- Continue monitoring
  monitoringThread monitorVar scalerVar configVar resourcesVar

adjustScale :: TVar AutoScaler -> AutoScaler -> IO ()
adjustScale scalerVar newState = atomically $ do
  writeTVar scalerVar newState
  -- Record scaling event
  now <- getCurrentTime
  resources <- readTVar (undefined :: TVar (Map.Map Int ResourceState))
  writeTVar scalerVar newState

-- | Acquire resource with full bulkhead isolation
acquireFullResource :: CircuitBreakerBulkheadFull -> IO (Either Text Int)
acquireFullResource breaker = do
  now <- getCurrentTime
  resources <- readTVarIO (cbResources breaker)
  config <- readTVarIO (cbConfig breaker)
  
  -- Check if we can create new resource
  let currentCount = Map.size resources
      maxAllowed = maxResources (config)
  
  if currentCount >= maxAllowed
    then do
      -- Check for failed resources to clean up
      let failed = filter (\(_, s) -> 
            case s of
              ResourceFailed _ _ -> True
              _ -> False) (Map.toList resources)
      if null failed
        then return $ Left "Bulkhead at maximum capacity"
        else do
          -- Clean up one failed resource
          let (failedId, _) = head failed
          let cleaned = Map.delete failedId resources
          atomically $ writeTVar (cbResources breaker) cleaned
          acquireFullResource breaker  -- Retry
    else do
      -- Create new resource
      let newId = currentCount + 1
      atomically $ do
        writeTVar (cbResources breaker) 
          (Map.insert newId (ResourceActive now 0) resources)
        m <- readTVar (cbMetrics breaker)
        writeTVar (cbMetrics breaker) m
          { totalRequests = totalRequests m + 1,
            activeResources = Map.size (Map.insert newId (ResourceActive now 0) resources),
            maxWaitTime = max (maxWaitTime m) 0
          }
      return $ Right newId

-- | Release resource with cleanup
releaseFullResource :: CircuitBreakerBulkheadFull -> Int -> IO ()
releaseFullResource breaker resourceId = do
  now <- getCurrentTime
  atomically $ do
    resources <- readTVar (cbResources breaker)
    case Map.lookup resourceId resources of
      Just (ResourceActive _ count) -> do
        let updated = Map.insert resourceId (ResourceIdle now) resources
        writeTVar (cbResources breaker) updated
        m <- readTVar (cbMetrics breaker)
        writeTVar (cbMetrics breaker) m
          { activeResources = Map.size (Map.filter (\s -> case s of ResourceActive{} -> True; _ -> False) updated),
            idleResources = Map.size (Map.filter (\s -> case s of ResourceIdle{} -> True; _ -> False) updated)
          }
      _ -> return ()

-- | Execute with full bulkhead protection
executeWithBulkheadFull :: CircuitBreakerBulkheadFull -> IO a -> IO (Either Text a)
executeWithBulkheadFull breaker action = do
  mbResource <- acquireFullResource breaker
  case mbResource of
    Left err -> return $ Left err
    Right resourceId -> do
      result <- try action
      case result of
        Right val -> do
          releaseFullResource breaker resourceId
          return $ Right val
        Left err -> do
          releaseFullResource breaker resourceId
          return $ Left err
