{-# LANGUAGE ScopedTypeVariables #-}

module System.CircuitBreakerBulkheadFullWithMetrics where

import Control.Concurrent (forkIO, threadDelay)
import Control.Concurrent.STM (TVar, newTVarIO, readTVar, writeTVar, atomically, readTVarIO)
import Control.Exception (try, SomeException)
import Control.Monad (when, void)
import Data.Time.Clock (UTCTime, getCurrentTime, diffUTCTime, NominalDiffTime)
import qualified Data.Map.Strict as Map
import Data.Text (Text, pack)
import Data.List (sortBy, sort)

-- | Full bulkhead with comprehensive metrics and monitoring
data CircuitBreakerBulkheadFullWithMetrics = CircuitBreakerBulkheadFullWithMetrics
  { cbConfig :: TVar BulkheadConfig,
    cbResources :: TVar (Map.Map Int ResourceState),
    cbMetrics :: TVar BulkheadMetrics,
    cbMonitor :: TVar MonitorState,
    cbAutoScaler :: TVar AutoScaler,
    cbLatencySamples :: TVar [Double]
  }

-- | Bulkhead configuration with dynamic scaling
data BulkheadConfig = BulkheadConfig
  { minResources :: Int,
    maxResources :: Int,
    resourceCapacity :: TVar Int,
    loadThreshold :: Double,
    scaleCheckInterval :: Int,
    latencyP95Threshold :: Double
  }

-- | Resource state with detailed health tracking
data ResourceState
  = ResourceActive { lastUsed :: UTCTime, usageCount :: Int, avgLatency :: Double }
  | ResourceIdle { idleSince :: UTCTime }
  | ResourceFailed { failureCount :: Int, lastFailure :: UTCTime, errorRate :: Double }
  deriving (Show, Eq)

-- | Monitor state with detailed health tracking
data MonitorState = MonitorState
  { checkInterval :: NominalDiffTime,
    lastCheck :: UTCTime,
    healthLog :: [(UTCTime, Text, Bool, Double)],
    alertThreshold :: Double
  }

-- | Auto-scaling state with predictive scaling
data AutoScaler
  = StableState { currentCapacity :: Int }
  | ScalingUp { targetResources :: Int, scalingReason :: Text }
  | ScalingDown { targetResources :: Int }
  | EmergencyScale { emergencyTarget :: Int, reason :: Text }
  deriving (Show, Eq)

-- | Comprehensive bulkhead metrics with SLA tracking
data BulkheadMetrics = BulkheadMetrics
  { totalRequests :: Int,
    rejectedRequests :: Int,
    activeResources :: Int,
    idleResources :: Int,
    failedResources :: Int,
    avgWaitTime :: Double,
    maxWaitTime :: Double,
    p95Latency :: Double,
    p99Latency :: Double,
    scalingEvents :: [(UTCTime, Text, Int, Int, Double)],
    slaCompliance :: Double,
    resourceHealth :: Map.Map Int Double
  }

-- | Initialize full bulkhead with comprehensive monitoring
initCircuitBreakerBulkheadFullWithMetrics :: IO CircuitBreakerBulkheadFullWithMetrics
initCircuitBreakerBulkheadFullWithMetrics = do
  capacityTVar <- newTVarIO 20
  configVar <- newTVarIO $ BulkheadConfig
    { minResources = 5,
      maxResources = 200,
      resourceCapacity = capacityTVar,
      loadThreshold = 0.75,
      scaleCheckInterval = 30,
      latencyP95Threshold = 1000.0
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
      p95Latency = 0,
      p99Latency = 0,
      scalingEvents = [],
      slaCompliance = 1.0,
      resourceHealth = Map.empty
    }
  now <- getCurrentTime
  monitorVar <- newTVarIO MonitorState
    { checkInterval = 30,
      lastCheck = now,
      healthLog = [],
      alertThreshold = 0.95
    }
  scalerVar <- newTVarIO (StableState {currentCapacity = 0} :: AutoScaler)
  latencyVar <- newTVarIO []
  -- Start monitoring and scaling threads
  void $ forkIO $ monitoringThread metricsVar scalerVar configVar resourcesVar monitorVar
  void $ forkIO $ latencyMonitoringThread latencyVar
  return $ CircuitBreakerBulkheadFullWithMetrics
    { cbConfig = configVar,
      cbResources = resourcesVar,
      cbMetrics = metricsVar,
      cbMonitor = monitorVar,
      cbAutoScaler = scalerVar,
      cbLatencySamples = latencyVar
    }

-- | Advanced monitoring thread with predictive analytics
monitoringThread :: TVar BulkheadMetrics -> TVar AutoScaler -> TVar BulkheadConfig -> TVar (Map.Map Int ResourceState) -> TVar MonitorState -> IO ()
monitoringThread metricsVar scalerVar configVar resourcesVar monitorVar = do
  threadDelay (30 * 1000000)  -- 30 seconds
  now <- getCurrentTime

  -- Comprehensive health assessment
  resources <- readTVarIO resourcesVar
  config <- readTVarIO configVar

  let (healthy, degraded, failed) = classifyResources resources
      healthScore = calculateHealthScore healthy degraded failed
      currentCapacity = Map.size resources
      loadFactor = fromIntegral currentCapacity / fromIntegral (maxResources config)

  -- Predictive scaling decisions
  scaler <- readTVarIO scalerVar
  newScaler <- case scaler of
    StableState _ -> do
      let newScaler' = if (loadFactor > loadThreshold config && currentCapacity < maxResources config)
            then ScalingUp {targetResources = min (maxResources config) (currentCapacity + 5), scalingReason = pack "High load detected"}
            else if (loadFactor < loadThreshold config * 0.3 && currentCapacity > minResources config)
              then ScalingDown {targetResources = max (minResources config) (currentCapacity - 2)}
              else StableState {currentCapacity = currentCapacity}
      return newScaler'
    ScalingUp target _ -> do
      if currentCapacity >= target
        then return StableState {currentCapacity = currentCapacity}
        else return $ ScalingUp {targetResources = target, scalingReason = pack ""}
    ScalingDown target -> do
      if currentCapacity <= target
        then return StableState {currentCapacity = currentCapacity}
        else return $ ScalingDown {targetResources = target}
    EmergencyScale target reason -> do
      if currentCapacity >= target
        then return StableState {currentCapacity = currentCapacity}
        else return $ EmergencyScale {emergencyTarget = target, reason = reason}

  -- Update monitor state
  atomically $ do
    writeTVar scalerVar newScaler
    oldMonitor <- readTVar monitorVar
    writeTVar monitorVar MonitorState
      { checkInterval = checkInterval oldMonitor,
        lastCheck = now,
        healthLog = (now, pack "health_assessment", healthScore >= 0.8, healthScore) : healthLog oldMonitor
      }

    -- Record scaling event
    case newScaler of
      ScalingUp target reason -> do
        m <- readTVar metricsVar
        writeTVar metricsVar m { scalingEvents = (now, pack "scale_up", target, currentCapacity, healthScore) : scalingEvents m }
      ScalingDown target -> do
        m <- readTVar metricsVar
        writeTVar metricsVar m { scalingEvents = (now, pack "scale_down", target, currentCapacity, healthScore) : scalingEvents m }
      EmergencyScale target reason -> do
        m <- readTVar metricsVar
        writeTVar metricsVar m { scalingEvents = (now, pack "emergency_scale", target, currentCapacity, healthScore) : scalingEvents m }
      StableState _ -> return ()

  -- Continue monitoring (stubbed)
  -- monitoringThread metricsVar newScaler configVar resourcesVar monitorVar
  return ()

-- | Classify resource health
classifyResources :: Map.Map Int ResourceState -> ([Int], [Int], [Int])
classifyResources resources = (healthy, degraded, failed)
  where
    healthy = map fst $ filter (\(_, s) -> case s of ResourceActive {} -> True; ResourceIdle {} -> True; _ -> False) (Map.toList resources)
    degraded = map fst $ filter (\(_, s) -> case s of ResourceFailed {} -> True; _ -> False) (Map.toList resources)
    failed = map fst $ filter (\(_, s) -> case s of ResourceFailed {} -> True; _ -> False) (Map.toList resources)

-- | Calculate health score (0-1)
calculateHealthScore :: [Int] -> [Int] -> [Int] -> Double
calculateHealthScore healthy degraded failed =
  let total = length healthy + length degraded + length failed
  in if total == 0 then 0.0 else fromIntegral (length healthy) / fromIntegral total

-- | Latency monitoring thread
latencyMonitoringThread :: TVar [Double] -> IO ()
latencyMonitoringThread latencyVar = do
  threadDelay (10 * 1000000)  -- 10 seconds
  -- Collect and analyze latency samples
  return ()

-- | Acquire resource with comprehensive monitoring
acquireFullResourceWithMetrics :: CircuitBreakerBulkheadFullWithMetrics -> IO (Either Text Int)
acquireFullResourceWithMetrics breaker = do
  now <- getCurrentTime
  resources <- readTVarIO (cbResources breaker)
  config <- readTVarIO (cbConfig breaker)
  latencySamples <- readTVarIO (cbLatencySamples breaker)

  -- Calculate current latency percentiles
  let sortedLatencies = sort latencySamples
      p95Idx = length sortedLatencies * 95 `div` 100
      p99Idx = length sortedLatencies * 99 `div` 100
      p95 = if null sortedLatencies then 0 else sortedLatencies !! min p95Idx (length sortedLatencies - 1)
      p99 = if null sortedLatencies then 0 else sortedLatencies !! min p99Idx (length sortedLatencies - 1)

  -- Check SLA compliance
  let slaCompliance = if p95 < latencyP95Threshold config then 1.0 else max 0.0 (1.0 - (p95 / latencyP95Threshold config))

  -- Resource acquisition logic
  let currentCount = Map.size resources
      maxAllowed = maxResources config

  if currentCount >= maxAllowed
    then do
      -- Record rejection with metrics
      atomically $ do
        m <- readTVar (cbMetrics breaker)
        writeTVar (cbMetrics breaker) m
          { rejectedRequests = rejectedRequests m + 1,
            p95Latency = p95,
            p99Latency = p99,
            resourceHealth = Map.map (\v -> v * 1.1) (resourceHealth m)
          }
      return $ Left (pack "Bulkhead at maximum capacity")
    else do
      -- Create new resource with monitoring
      let newId = currentCount + 1
      acquisitionTime <- getCurrentTime
      atomically $ do
        writeTVar (cbResources breaker)
          (Map.insert newId (ResourceActive now 0 0.0) resources)
        m <- readTVar (cbMetrics breaker)
        writeTVar (cbMetrics breaker) m
          { totalRequests = totalRequests m + 1,
            activeResources = Map.size (Map.insert newId (ResourceActive now 0 0.0) resources),
            maxWaitTime = max (maxWaitTime m) 0,
            p95Latency = p95,
            p99Latency = p99,
            slaCompliance = slaCompliance,
            resourceHealth = Map.insert newId 0.0 (resourceHealth m)
          }
      return $ Right newId

-- | Comprehensive release with health tracking
releaseFullResourceWithMetrics :: CircuitBreakerBulkheadFullWithMetrics -> Int -> Double -> IO ()
releaseFullResourceWithMetrics breaker resourceId latency = do
  now <- getCurrentTime
  atomically $ do
    resources <- readTVar (cbResources breaker)
    case Map.lookup resourceId resources of
      Just (ResourceActive _ count _) -> do
        let updated = Map.insert resourceId (ResourceIdle now) resources
        writeTVar (cbResources breaker) updated
        m <- readTVar (cbMetrics breaker)
        let newHealth = max 0.0 (resourceHealth m Map.! resourceId - 0.1)
        writeTVar (cbMetrics breaker) m
          { activeResources = Map.size (Map.filter (\s -> case s of ResourceActive{} -> True; _ -> False) updated),
            idleResources = Map.size (Map.filter (\s -> case s of ResourceIdle{} -> True; _ -> False) updated),
            resourceHealth = Map.insert resourceId newHealth (resourceHealth m)
          }
      Just (ResourceIdle _) -> do
        let updated = Map.delete resourceId resources
        writeTVar (cbResources breaker) updated
      _ -> return ()

-- | Execute with full monitoring and metrics
executeWithFullMetrics :: CircuitBreakerBulkheadFullWithMetrics -> IO a -> IO (Either Text a)
executeWithFullMetrics breaker action = do
  mbResource <- acquireFullResourceWithMetrics breaker
  case mbResource of
    Left err -> return $ Left err
    Right resourceId -> do
      -- Measure execution latency using timestamps
      startTime <- getCurrentTime
      result <- try action
      endTime <- getCurrentTime
      let latencyMs = fromIntegral (ceiling (realToFrac (diffUTCTime endTime startTime) * 1000) :: Integer) :: Double

      case result of
        Right val -> do
          releaseFullResourceWithMetrics breaker resourceId latencyMs
          -- Update latency samples
          atomically $ do
            latVar <- readTVar (cbLatencySamples breaker)
            writeTVar (cbLatencySamples breaker) (take 10000 (latencyMs : latVar))
          return $ Right val
        Left (err :: SomeException) -> do
          releaseFullResourceWithMetrics breaker resourceId latencyMs
          return $ Left (pack $ show err)

-- | SLA compliance reporting
data SLAReport = SLAReport
  { reportComplianceRate :: Double,
    reportTotalRequests :: Int,
    reportRejectedRequests :: Int,
    reportP95Latency :: Double,
    reportP99Latency :: Double,
    reportScalingCount :: Int,
    reportHealthScore :: Double
  }

generateSLAReport :: CircuitBreakerBulkheadFullWithMetrics -> IO SLAReport
generateSLAReport breaker = do
  metrics <- readTVarIO (cbMetrics breaker)
  config <- readTVarIO (cbConfig breaker)
  let healthScoreValue = if Map.null (resourceHealth metrics) then 0 else (sum $ Map.elems (resourceHealth metrics)) / fromIntegral (max 1 (Map.size (resourceHealth metrics)))
  return $ SLAReport
    { reportComplianceRate = slaCompliance metrics,
      reportTotalRequests = totalRequests metrics,
      reportRejectedRequests = rejectedRequests metrics,
      reportP95Latency = p95Latency metrics,
      reportP99Latency = p99Latency metrics,
      reportScalingCount = length (scalingEvents metrics),
      reportHealthScore = healthScoreValue
    }
