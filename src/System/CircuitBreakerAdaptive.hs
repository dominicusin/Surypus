module System.CircuitBreakerAdaptive where

import Control.Concurrent.STM (TVar, atomically, newTVarIO, readTVar, writeTVar)
import Data.List (sort)
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import Data.Time.Clock (UTCTime, diffUTCTime, getCurrentTime)

-- | Adaptive circuit breaker that learns from traffic patterns
data CircuitBreakerAdaptive = CircuitBreakerAdaptive
  { cbStateVar :: TVar CBState,
    cbFailures :: TVar [UTCTime],
    cbSuccesses :: TVar Int,
    cbConfig :: CircuitConfig,
    cbMetrics :: TVar CBMetrics,
    cbHistory :: TVar [(UTCTime, CBState)],
    cbTrafficPattern :: TVar TrafficPattern,
    cbAdaptiveThreshold :: TVar Double
  }

-- | Circuit states with adaptive threshold
data CBState
  = CBSClosed {closedThreshold :: Int}
  | CBSOpen {openSince :: UTCTime, openReason :: Text}
  | CBSHalfOpen {halfOpenAttempts :: Int}
  | CBSDisabled
  deriving (Show, Eq)

-- | Traffic pattern analysis
data TrafficPattern
  = LowTraffic
  | MediumTraffic
  | HighTraffic
  | BurstTraffic
  deriving (Show, Eq)

-- | Circuit configuration
data CircuitConfig = CircuitConfig
  { baseFailureThreshold :: Int,
    resetTimeoutSec :: Int,
    halfOpenMaxCalls :: Int,
    failureRateThreshold :: Double,
    successThreshold :: Double,
    adaptationRate :: Double
  }

-- | Circuit metrics with adaptive behavior
data CBMetrics = CBMetrics
  { totalRequests :: Int,
    totalFailures :: Int,
    totalSuccesses :: Int,
    failureRate :: Double,
    lastStateTransition :: UTCTime,
    adaptationSteps :: Int,
    trafficVolatility :: Double
  }

-- | Initialize adaptive circuit breaker
initCircuitBreakerAdaptive :: CircuitConfig -> IO CircuitBreakerAdaptive

initBreaker config = do
  stateVar <- newTVarIO (CBSClosed (baseFailureThreshold config))
  failuresVar <- newTVarIO []
  successesVar <- newTVarIO 0
  historyVar <- newTVarIO []
  patternVar <- newTVarIO LowTraffic
  thresholdVar <- newTVarIO (fromIntegral (baseFailureThreshold config))
  metricsVar <-
    newTVarIO
      CBMetrics
        { totalRequests = 0,
          totalFailures = 0,
          totalSuccesses = 0,
          failureRate = 0,
          lastStateTransition = =<< getCurrentTime,
          adaptationSteps = 0,
          trafficVolatility = 0
        }
  return $
    CircuitBreakerAdaptive
      { cbStateVar = stateVar,
        cbFailures = failuresVar,
        cbSuccesses = successesVar,
        cbConfig = config,
        cbMetrics = metricsVar,
        cbHistory = historyVar,
        cbTrafficPattern = patternVar,
        cbAdaptiveThreshold = thresholdVar
      }

-- | Analyze traffic pattern
detectTrafficPattern :: [UTCTime] -> TrafficPattern
detectTrafficPattern timestamps =
  let intervals = zipWith diffUTCTime (tail timestamps) timestamps
      avgInterval = if null intervals then 0 else sum intervals / fromIntegral (length intervals)
      variance = sum (map (\t -> (t - avgInterval) ** 2) intervals) / fromIntegral (max 1 (length intervals - 1))
      cv = sqrt variance / avgInterval -- Coefficient of variation
   in case () of
        _
          | length timestamps < 2 -> LowTraffic
          | cv < 0.1 -> LowTraffic
          | cv < 0.5 -> MediumTraffic
          | cv < 1.0 -> HighTraffic
          | otherwise -> BurstTraffic

-- | Adapt threshold based on traffic
adaptThreshold :: CircuitBreakerAdaptive -> IO ()
adaptThreshold breaker = do
  now <- getCurrentTime
  failures <- readTVar (cbFailures breaker)
  pattern <- readTVarIO (cbTrafficPattern breaker)
  let interval = case pattern of
        LowTraffic -> 60 -- Check every minute
        MediumTraffic -> 30
        HighTraffic -> 10
        BurstTraffic -> 5
  if diffUTCTime now (lastStateTransition =<< readTVarIO (cbStateVar breaker)) > fromIntegral interval
    then do
      pattern' <- detectTrafficPattern <$> readTVarIO (cbFailures breaker)
      writeTVar (cbTrafficPattern breaker) pattern'
      -- Adjust threshold based on pattern
      let base = fromIntegral (baseFailureThreshold (cbConfig breaker))
          adjusted = case pattern' of
            LowTraffic -> base * 0.8
            MediumTraffic -> base
            HighTraffic -> base * 1.5
            BurstTraffic -> base * 2.0
      -- Smooth adaptation
      oldThreshold <- readTVarIO (cbAdaptiveThreshold breaker)
      let newThreshold =
            oldThreshold * (1 - adaptationRate (cbConfig breaker))
              + adjusted * adaptationRate (cbConfig breaker)
      writeTVar (cbAdaptiveThreshold breaker) newThreshold
      writeTVar (cbHistory breaker) ((now, CBSClosed (floor newThreshold)) :)
    else return ()

-- | Execute with adaptive circuit breaker
executeWithCircuitAdaptive :: CircuitBreakerAdaptive -> IO a -> IO (Either Text a)
executeWithCircuitAdaptive breaker action = do
  adaptThreshold breaker
  threshold <- readTVarIO (cbAdaptiveThreshold breaker)
  state <- readTVarIO (cbStateVar breaker)
  now <- getCurrentTime

  case state of
    CBSDisabled -> return $ Left "Circuit breaker disabled"
    CBSOpen reason since ->
      if diffUTCTime now since >= fromIntegral (resetTimeoutSec (cbConfig breaker))
        then tryHalfOpen breaker action
        else return $ Left $ "Circuit open: " <> reason
    CBSClosed _ -> do
      result <- tryAction breaker action now threshold
      case result of
        Right val -> do
          atomically $ do
            s <- readTVar (cbSuccesses breaker)
            writeTVar (cbSuccesses breaker) (s + 1)
            updateMetrics breaker now (Right val)
          return $ Right val
        Left err -> do
          atomically $ do
            f <- readTVar (cbFailures breaker)
            writeTVar (cbFailures breaker) (f ++ [now])
            updateMetrics breaker now (Left err)
          checkFailureThreshold breaker now threshold
          return $ Left err
    CBSHalfOpen attempts -> do
      if attempts >= halfOpenMaxCalls (cbConfig breaker)
        then return $ Left "Half-open limit reached"
        else do
          result <- tryAction breaker action now threshold
          case result of
            Right val -> do
              atomically $ do
                s <- readTVar (cbSuccesses breaker)
                writeTVar (cbSuccesses breaker) (s + 1)
                updateMetrics breaker now (Right val)
              return $ Right val
            Left err -> do
              atomically $ do
                f <- readTVar (cbFailures breaker)
                writeTVar (cbFailures breaker) (f ++ [now])
                updateMetrics breaker now (Left err)
              return $ Left err
  where
    tryAction _ act now' thresholdVal = do
      result <- try act
      case result of
        Right val -> return $ Right val
        Left err -> return $ Left err

    checkFailureThreshold breaker' now' thresholdVal = do
      failures <- readTVar (cbFailures breaker')
      let recent = filter (>= diffUTCTime now' . subtract (fromIntegral (resetTimeoutSec (cbConfig breaker')) * 2)) failures
      when (length recent >= floor thresholdVal) $
        writeTVar (cbStateVar breaker') (CBSOpen "adaptive threshold exceeded" now')

    updateMetrics breaker' now' result = do
      m <- readTVar (cbMetrics breaker')
      let newM = case result of
            Right _ ->
              m
                { totalRequests = totalRequests m + 1,
                  totalSuccesses = totalSuccesses m + 1,
                  failureRate = fromIntegral (totalFailures m + 1) / fromIntegral (totalRequests m + 1),
                  lastStateTransition = now'
                }
            Left _ ->
              m
                { totalRequests = totalRequests m + 1,
                  totalFailures = totalFailures m + 1,
                  failureRate = fromIntegral (totalFailures m + 1) / fromIntegral (totalRequests m + 1),
                  lastStateTransition = now'
                }
      writeTVar (cbMetrics breaker') newM
