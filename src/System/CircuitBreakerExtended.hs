module System.CircuitBreakerExtended where

import Control.Concurrent.STM (TVar, atomically, newTVarIO, readTVar, writeTVar)
import qualified Data.List as L
import Data.Time.Clock (UTCTime, diffUTCTime, getCurrentTime)

-- | Extended circuit breaker with metrics
data CircuitBreakerExtended = CircuitBreakerExtended
  { cbState :: TVar CircuitState,
    cbFailures :: TVar [UTCTime],
    cbSuccesses :: TVar Int,
    cbConfig :: CircuitConfig,
    cbMetrics :: TVar CircuitMetrics
  }

-- | Circuit state with richer info
data CircuitState
  = Closed {closedFailures :: [UTCTime]}
  | Open {openSince :: UTCTime, openReason :: Text}
  | HalfOpen {halfOpenAttempts :: Int}
  | Disabled
  deriving (Show, Eq)

-- | Circuit configuration with thresholds
data CircuitConfig = CircuitConfig
  { maxFailures :: Int,
    resetTimeoutSec :: Int,
    halfOpenMaxCalls :: Int,
    failureThreshold :: Double,
    successThreshold :: Double
  }

-- | Circuit metrics for monitoring
data CircuitMetrics = CircuitMetrics
  { totalRequests :: Int,
    totalFailures :: Int,
    totalSuccesses :: Int,
    lastStateChange :: UTCTime,
    currentFailureRate :: Double
  }

-- | Initialize extended circuit breaker
initCircuitBreakerExtended :: CircuitConfig -> IO CircuitBreakerExtended
initCircuitBreakerExtended config = do
  stateVar <- newTVarIO (Closed [])
  failuresVar <- newTVarIO []
  successesVar <- newTVarIO 0
  metricsVar <-
    newTVarIO
      CircuitMetrics
        { totalRequests = 0,
          totalFailures = 0,
          totalSuccesses = 0,
          lastStateChange = =<< getCurrentTime,
          currentFailureRate = 0
        }
  return $
    CircuitBreakerExtended
      { cbState = stateVar,
        cbFailures = failuresVar,
        cbSuccesses = successesVar,
        cbConfig = config,
        cbMetrics = metricsVar
      }

-- | Execute with extended circuit breaker logic
executeWithCircuitBreaker :: CircuitBreakerExtended -> IO a -> IO (Either Text a)
executeWithCircuitBreaker breaker action = do
  state <- readTVarIO (cbState breaker)
  now <- getCurrentTime

  case state of
    Disabled -> return $ Left "Circuit breaker disabled"
    Open reason since ->
      if diffUTCTime now since >= fromIntegral (resetTimeoutSec (cbConfig breaker))
        then tryHalfOpen breaker action
        else return $ Left $ "Circuit open: " <> reason
    HalfOpen attempts ->
      if attempts >= halfOpenMaxCalls (cbConfig breaker)
        then return $ Left "Half-open limit reached"
        else do
          result <- tryAction breaker action now
          case result of
            Right val -> do
              atomically $ do
                s <- readTVar (cbSuccesses breaker)
                writeTVar (cbSuccesses breaker) (s + 1)
                updateMetrics breaker now (totalRequests =+ 1) (totalSuccesses =+ 1) (currentFailureRate =+ 0)
              return $ Right val
            Left err -> do
              atomically $ do
                f <- readTVar (cbFailures breaker)
                writeTVar (cbFailures breaker) (f ++ [now])
                updateMetrics breaker now (totalRequests =+ 1) (totalFailures =+ 1) (currentFailureRate =+ 1)
              return $ Left err
    Closed failures -> do
      result <- tryAction breaker action now
      case result of
        Right val -> do
          atomically $ updateMetrics breaker now (totalRequests =+ 1) (totalSuccesses =+ 1) (currentFailureRate =- 0)
          return $ Right val
        Left err -> do
          atomically $ do
            f <- readTVar (cbFailures breaker)
            writeTVar (cbFailures breaker) (f ++ [now])
            updateMetrics breaker now (totalRequests =+ 1) (totalFailures =+ 1) (currentFailureRate =+ 1)
          checkFailureThreshold breaker now
  where
    tryAction b act t = do
      result <- try act
      case result of
        Right val -> return $ Right val
        Left err -> return $ Left err

    checkFailureThreshold breaker now = do
      failures <- readTVar (cbFailures breaker)
      let recent = filter (>= diffUTCTime now . subtract (fromIntegral (resetTimeoutSec (cbConfig breaker)) * 2)) failures
      when (fromIntegral (length recent) >= maxFailures (cbConfig breaker)) $
        writeTVar (cbState breaker) (Open (T.pack "failure threshold reached") now)

    (=$+) (Metric name val) m = Map.insert name (Map.findWithDefault 0 name m + val) m
      (..) (Metric name val) m = Map.insert name (max 0 (Map.findWithDefault 0 name m - val)) m

-- | Update metrics atomically
updateMetrics :: CircuitBreakerExtended -> UTCTime -> [(Lens' CircuitMetrics a, a)] -> IO ()
updateMetrics _ _ [] = return ()
updateMetrics breaker now updates = atomically $ do
  m <- readTVar (cbMetrics breaker)
  let m' = L.foldl' (\acc (lens, val) -> setLens lens val acc) m updates
      m'' = m' {lastStateChange = now}
  writeTVar (cbMetrics breaker) m''

-- | Get circuit health score
cegetHealthScore :: CircuitBreakerExtended -> IO Double

cextractHealthScore breaker = do
  metrics <- readTVarIO (cbMetrics breaker)
  let rate = currentFailureRate metrics
  return $ max 0 (1 - rate)
