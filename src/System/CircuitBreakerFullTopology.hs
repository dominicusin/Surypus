module System.CircuitBreakerFullTopology where

import Control.Concurrent.STM (TVar, atomically, newTVarIO, readTVar, writeTVar)
import Data.List (partition)
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import Data.Time.Clock (UTCTime, diffUTCTime, getCurrentTime)

-- | Full circuit breaker with topology and advanced failure modes
data CircuitBreakerFullTopology = CircuitBreakerFullTopology
  { cbStateVar :: TVar CBState,
    cbFailures :: TVar [UTCTime],
    cbSuccesses :: TVar Int,
    cbConfig :: CircuitConfig,
    cbMetrics :: TVar CBMetrics,
    cbHistory :: TVar [(UTCTime, CBState)],
    cbTopology :: TVar CircuitTopology
  }

-- | Circuit states with topology awareness
data CBState
  = CBSClosed {closedThreshold :: Int, closedTopology :: CircuitTopology}
  | CBSOpen {openSince :: UTCTime, openReason :: Text}
  | CBSHalfOpen {halfOpenAttempts :: Int}
  | CBSDisabled
  deriving (Show, Eq)

-- | Circuit topology definitions
data CircuitTopology
  = SeriesTopology [CircuitNode]
  | ParallelTopology [CircuitNode]
  | StarTopology CircuitNode [CircuitNode]
  | MeshTopology [[CircuitNode]]
  deriving (Show, Eq)

-- | Circuit node with health status
data CircuitNode = CircuitNode
  { nodeId :: Text,
    nodeType :: Text,
    nodeThreshold :: Int,
    nodeStatus :: TVar NodeStatus,
    nodeMetrics :: TVar NodeMetrics
  }

-- | Node operational status
data NodeStatus
  = NodeActive
  | NodeFailed
  | NodeDegraded
  deriving (Show, Eq)

-- | Node performance metrics
data NodeMetrics = NodeMetrics
  { nodeRequestCount :: Int,
    nodeFailureCount :: Int,
    nodeAvgLatency :: Double,
    nodeLastCheck :: UTCTime
  }

-- | Circuit configuration
data CircuitConfig = CircuitConfig
  { failureThresholdCount :: Int,
    resetTimeoutSec :: Int,
    halfOpenMaxCalls :: Int,
    failureRateThreshold :: Double,
    successThreshold :: Double
  }

-- | Circuit system-wide metrics
data CBMetrics = CBMetrics
  { totalRequests :: Int,
    totalFailures :: Int,
    totalSuccesses :: Int,
    failureRate :: Double,
    lastStateTransition :: UTCTime,
    topologyChanges :: Int,
    nodeStatusChanges :: Int
  }

-- | Initialize full circuit breaker with topology
initCircuitBreakerFullTopology :: CircuitConfig -> CircuitTopology -> IO CircuitBreakerFullTopology
initCircuitBreakerFullTopology config topology = do
  stateVar <- newTVarIO (CBSClosed 0 topology)
  failuresVar <- newTVarIO []
  successesVar <- newTVarIO 0
  historyVar <- newTVarIO []
  topologyVar <- newTVarIO topology
  metricsVar <-
    newTVarIO
      CBMetrics
        { totalRequests = 0,
          totalFailures = 0,
          totalSuccesses = 0,
          failureRate = 0,
          lastStateTransition = =<< getCurrentTime,
          topologyChanges = 0,
          nodeStatusChanges = 0
        }
  return $
    CircuitBreakerFullTopology
      { cbStateVar = stateVar,
        cbFailures = failuresVar,
        cbSuccesses = successesVar,
        cbConfig = config,
        cbMetrics = metricsVar,
        cbHistory = historyVar,
        cbTopology = topologyVar
      }

-- | Execute with full circuit protection, topology awareness, and node-level health
executeWithCircuitFullTopology :: CircuitBreakerFullTopology -> IO a -> IO (Either Text a)
executeWithCircuitFullTopology breaker action = do
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

    topologyChange breaker' newTopology = atomically $ do
      oldTop <- readTVar (cbTopology breaker')
      when (oldTop /= newTopology) $ do
        writeTVar (cbTopology breaker') newTop
        h <- readTVar (cbHistory breaker')
        writeTVar (cbHistory breaker') ((now, state) : h)
        m <- readTVar (cbMetrics breaker')
        writeTVar (cbMetrics breaker') m {topologyChanges = topologyChanges m + 1}
