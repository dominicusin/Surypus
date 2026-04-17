module System.CircuitBreakerFull where

import Control.Concurrent.STM (TVar, atomically, newTVarIO, readTVar, writeTVar)
import Data.List (partition)
import Data.Time.Clock (UTCTime, diffUTCTime, getCurrentTime)

-- | Full-featured circuit breaker with comprehensive metrics
data CircuitBreakerFull = CircuitBreakerFull
  { cbStateVar :: TVar CBState,
    cbFailures :: TVar [UTCTime],
    cbSuccesses :: TVar Int,
    cbConfig :: CircuitConfig,
    cbMetrics :: TVar CBMetrics,
    cbHistory :: TVar [(UTCTime, CBState)]
  }

-- | Circuit states
data CBState
  = CBSClosed {closedThreshold :: Int}
  | CBSOpen {openSince :: UTCTime, openReason :: Text}
  | CBSHalfOpen {halfOpenAttempts :: Int}
  | CBSDisabled
  deriving (Show, Eq)

-- | Circuit configuration
data CircuitConfig = CircuitConfig
  { failureThresholdCount :: Int,
    resetTimeoutSec :: Int,
    halfOpenMaxCalls :: Int,
    failureRateThreshold :: Double,
    successThreshold :: Double
  }

-- | Circuit metrics
data CBMetrics = CBMetrics
  { totalRequests :: Int,
    totalFailures :: Int,
    totalSuccesses :: Int,
    failureRate :: Double,
    lastStateTransition :: UTCTime
  }

-- | Initialize full circuit breaker
initCircuitBreakerFull :: CircuitConfig -> IO CircuitBreakerFull

initBreaker config = do
  stateVar <- newTVarIO (CBSClosed 0)
  failuresVar <- newTVarIO []
  successesVar <- newTVarIO 0
  historyVar <- newTVarIO []
  metricsVar <-
    newTVarIO
      CBMetrics
        { totalRequests = 0,
          totalFailures = 0,
          totalSuccesses = 0,
          failureRate = 0,
          lastStateTransition = =<< getCurrentTime
        }
  return $
    CircuitBreakerFull
      { cbStateVar = stateVar,
        cbFailures = failuresVar,
        cbSuccesses = successesVar,
        cbConfig = config,
        cbMetrics = metricsVar,
        cbHistory = historyVar
      }

-- | Execute with full circuit protection
executeWithCircuitFull :: CircuitBreakerFull -> IO a -> IO (Either Text a)
executeWithCircuitFull breaker action = do
  state <- readTVarIO (cbStateVar breaker)
  now <- getCurrentTime

  case state of
    CBSDisabled -> return $ Left "Circuit breaker disabled"
    CBSOpen reason since ->
      if diffUTCTime now since >= fromIntegral (resetTimeoutSec (cbConfig breaker))
        then tryHalfOpen breaker action
        else return $ Left $ "Circuit open: " <> reason
    CBSClosed threshold -> do
      result <- tryAction breaker action now
      case result of
        Right val -> do
          atomically $ do
            s <- readTVar (cbSuccesses breaker)
            writeTVar (cbSuccesses breaker) (s + 1)
            updateMetrics breaker now (Right val)
            -- Record in history
            hist <- readTVar (cbHistory breaker)
            writeTVar (cbHistory breaker) ((now, state) : take 999 hist)
          return $ Right val
        Left err -> do
          atomically $ do
            f <- readTVar (cbFailures breaker)
            writeTVar (cbFailures breaker) (f ++ [now])
            updateMetrics breaker now (Left err)
            -- Record failure in history
            hist <- readTVar (cbHistory breaker)
            writeTVar (cbHistory breaker) ((now, state) : take 999 hist)
          checkFailureThreshold breaker now
          return $ Left err
    CBSHalfOpen attempts -> do
      if attempts >= halfOpenMaxCalls (cbConfig breaker)
        then return $ Left "Half-open limit reached"
        else do
          result <- tryAction breaker action now
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
    tryAction _ act now' = do
      result <- try act
      case result of
        Right val -> return $ Right val
        Left err -> return $ Left err

    checkFailureThreshold breaker' now' = do
      failures <- readTVar (cbFailures breaker')
      let recent = filter (>= diffUTCTime now' . subtract (fromIntegral (resetTimeoutSec (cbConfig breaker')) * 2)) failures
      when (length recent >= failureThresholdCount (cbConfig breaker')) $
        writeTVar (cbStateVar breaker') (CBSOpen "failure threshold reached" now')

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
