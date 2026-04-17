module System.CircuitBreakerSelfHealing where

import Control.Concurrent.STM (TVar, atomically, newTVarIO, readTVar, writeTVar)
import Data.List (sort)
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import Data.Time.Clock (UTCTime, diffUTCTime, getCurrentTime)

-- | Self-healing circuit breaker with automatic recovery
data CircuitBreakerSelfHealing = CircuitBreakerSelfHealing
  { cbStateVar :: TVar CBState,
    cbFailures :: TVar [UTCTime],
    cbSuccesses :: TVar Int,
    cbConfig :: CircuitConfig,
    cbMetrics :: TVar CBMetrics,
    cbHistory :: TVar [(UTCTime, CBState)],
    cbHealthCheckInterval :: TVar NominalDiffTime,
    cbAutoRecovery :: TVar Bool
  }

-- | Circuit states with self-healing
data CBState
  = CBSHealthy
  | CBSUnhealthy {unhealthySince :: UTCTime, recoveryAttempts :: Int}
  | CBSRecovering {recoveryStartTime :: UTCTime}
  | CBSRecovered
  | CBSDisabled
  deriving (Show, Eq)

-- | Circuit configuration
data CircuitConfig = CircuitConfig
  { healthCheckEndpoint :: Text,
    maxRecoveryAttempts :: Int,
    recoveryBackoffSeconds :: Int,
    failureThreshold :: Int,
    resetTimeoutSec :: Int,
    halfOpenMaxCalls :: Int
  }

-- | Circuit metrics with healing indicators
data CBMetrics = CBMetrics
  { totalRequests :: Int,
    totalFailures :: Int,
    totalSuccesses :: Int,
    failureRate :: Double,
    lastStateTransition :: UTCTime,
    healingCycles :: Int,
    autoRecoveryEnabled :: Bool,
    lastHealthCheck :: UTCTime,
    healthCheckSuccessRate :: Double
  }

-- | Initialize self-healing circuit breaker
initCircuitBreakerSelfHealing :: CircuitConfig -> IO CircuitBreakerSelfHealing

initBreaker config = do
  stateVar <- newTVarIO CBSHealthy
  failuresVar <- newTVarIO []
  successesVar <- newTVarIO 0
  historyVar <- newTVarIO []
  intervalVar <- newTVarIO 30 -- Check every 30 seconds
  recoveryVar <- newTVarIO True
  metricsVar <-
    newTVarIO
      CBMetrics
        { totalRequests = 0,
          totalFailures = 0,
          totalSuccesses = 0,
          failureRate = 0,
          lastStateTransition = =<< getCurrentTime,
          healingCycles = 0,
          autoRecoveryEnabled = True,
          lastHealthCheck = =<< getCurrentTime,
          healthCheckSuccessRate = 1.0
        }
  return $
    CircuitBreakerSelfHealing
      { cbStateVar = stateVar,
        cbFailures = failuresVar,
        cbSuccesses = successesVar,
        cbConfig = config,
        cbMetrics = metricsVar,
        cbHistory = historyVar,
        cbHealthCheckInterval = intervalVar,
        cbAutoRecovery = recoveryVar
      }

-- | Perform health check
performHealthCheck :: CircuitBreakerSelfHealing -> IO Bool
performHealthCheck breaker = do
  -- Simulate health check to external service
  -- In real implementation, this would call healthCheckEndpoint
  return True -- Placeholder

-- | Self-healing logic
attemptRecovery :: CircuitBreakerSelfHealing -> IO ()
attemptRecovery breaker = do
  autoRecover <- readTVarIO (cbAutoRecovery breaker)
  when autoRecover $ do
    now <- getCurrentTime
    state <- readTVarIO (cbStateVar breaker)

    case state of
      CBSUnhealthy _ attempts -> do
        let maxAttempts = maxRecoveryAttempts (cbConfig breaker)
        if attempts >= maxAttempts
          then do
            -- Escalate: disable circuit breaker
            writeTVar (cbStateVar breaker) CBSDisabled
            writeTVar (cbHistory breaker) ((now, CBSDisabled) :)
          else do
            -- Try recovery
            healthy <- performHealthCheck breaker
            if healthy
              then do
                writeTVar (cbStateVar breaker) CBSRecovering
                writeTVar (cbHistory breaker) ((now, CBSRecovering) :)
              else do
                -- Increment failure count
                atomically $ do
                  f <- readTVar (cbFailures breaker)
                  writeTVar (cbFailures breaker) (f ++ [now])
        -- Schedule next check
        interval <- readTVarIO (cbHealthCheckInterval breaker)
        -- In real implementation, use timer
        return ()
      CBSHealthy -> return ()
      CBSRecovered -> do
        -- Verify continued health
        healthy <- performHealthCheck breaker
        if healthy
          then return ()
          else do
            writeTVar (cbStateVar breaker) (CBSUnhealthy =<< getCurrentTime <*> newTVarIO 0)
      _ -> return ()

-- | Execute with self-healing circuit breaker
executeWithCircuitSelfHealing :: CircuitBreakerSelfHealing -> IO a -> IO (Either Text a)
executeWithCircuitSelfHealing breaker action = do
  -- Start background recovery process
  _ <- forkIO $ forever $ do
    threadDelay (10 * 1000000) -- 10 seconds
    attemptRecovery breaker
    return ()

  -- Execute action
  now <- getCurrentTime
  state <- readTVarIO (cbStateVar breaker)

  case state of
    CBSDisabled -> return $ Left "Circuit breaker disabled - requires manual intervention"
    CBSUnhealthy _ attempts -> do
      let maxAttempts = maxRecoveryAttempts (cbConfig breaker)
      if attempts >= maxAttempts
        then return $ Left "Service unhealthy - maximum recovery attempts exceeded"
        else executeAction breaker action now
    CBSRecovering _ -> return $ Left "Service recovering - try again later"
    CBSRecovered -> executeAction breaker action now
    CBSHealthy -> executeAction breaker action now
  where
    executeAction b act now' = do
      result <- try act
      case result of
        Right val -> do
          atomically $ do
            s <- readTVar (cbSuccesses b)
            writeTVar (cbSuccesses b) (s + 1)
            updateMetrics b now' (Right val)
          return $ Right val
        Left err -> do
          atomically $ do
            f <- readTVar (cbFailures b)
            writeTVar (cbFailures b) (f ++ [now'])
            updateMetrics b now' (Left err)
          return $ Left err

    updateMetrics b now' result = do
      m <- readTVar (cbMetrics b)
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
      writeTVar (cbMetrics b) newM

-- | Enable/disable auto recovery
setAutoRecovery :: CircuitBreakerSelfHealing -> Bool -> IO ()
setAutoRecovery breaker enabled = atomically $ writeTVar (cbAutoRecovery breaker) enabled
