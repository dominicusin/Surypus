module System.CircuitBreakerChained where

import Control.Concurrent.STM (TVar, atomically, newTVarIO, readTVar, writeTVar)
import Control.Exception (try, SomeException)
import Data.List (intercalate)
import Data.Text (Text)
import Data.Time.Clock (UTCTime, getCurrentTime)

-- | Chained circuit breakers for microservices
data CircuitBreakerChained = CircuitBreakerChained
  { cbServiceName :: Text,
    cbBreaker :: CircuitBreakerFull,
    cbNextBreaker :: Maybe CircuitBreakerChained,
    cbMetrics :: TVar ChainMetrics
  }

-- | Full circuit breaker (imported from previous module)
data CircuitBreakerFull = CircuitBreakerFull
  { cbStateVar :: TVar CBState,
    cbFailures :: TVar [UTCTime],
    cbSuccesses :: TVar Int,
    cbConfig :: CircuitConfig,
    cbMetrics :: TVar CBMetrics,
    cbHistory :: TVar [(UTCTime, CBState)]
  }

-- | Chain metrics
data ChainMetrics = ChainMetrics
  { chainTotalRequests :: Int,
    chainTotalFailures :: Int,
    chainLatencyMap :: Map.Map Text [Double],
    chainServiceOrder :: [Text]
  }

-- | Circuit states
data CBState
  = CBSClosed Int
  | CBSOpen UTCTime Text
  | CBSHalfOpen Int
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

-- | Initialize chained circuit breaker
initCircuitBreakerChained :: Text -> CircuitConfig -> IO CircuitBreakerChained

initBreaker name config = do
  stateVar <- newTVarIO (CBSClosed 0)
  failuresVar <- newTVarIO []
  successesVar <- newTVarIO 0
  historyVar <- newTVarIO []
  metricsVar <-
    newTVarIO
      ChainMetrics
        { chainTotalRequests = 0,
          chainTotalFailures = 0,
          chainLatencyMap = Map.empty,
          chainServiceOrder = [name]
        }
  return $
    CircuitBreakerChained
      { cbServiceName = name,
        cbBreaker =
          CircuitBreakerFull
            { cbStateVar = stateVar,
              cbFailures = failuresVar,
              cbSuccesses = successesVar,
              cbConfig = config,
              cbMetrics = metricsVar,
              cbHistory = historyVar
            },
        cbNextBreaker = Nothing,
        cbMetrics = metricsVar
      }

-- | Chain multiple circuit breakers
chainBreakers :: CircuitBreakerChained -> CircuitBreakerChained -> CircuitBreakerChained
chainBreakers prev next = prev {cbNextBreaker = Just next}

-- | Execute through chain
executeChain :: CircuitBreakerChained -> IO a -> IO (Either Text a)
executeChain chain action = do
  -- Execute current service
  result <- executeService (cbBreaker chain) action
  case result of
    Left err -> do
      -- Record failure in chain metrics
      atomically $ do
        m <- readTVar (cbMetrics chain)
        writeTVar
          (cbMetrics chain)
          m
            { chainTotalFailures = chainTotalFailures m + 1,
              chainLatencyMap = Map.insert (cbServiceName chain) [] (chainLatencyMap m)
            }
      -- Try next service in chain if available
      case cbNextBreaker chain of
        Nothing -> return $ Left err
        Just next -> executeChain next action
    Right val -> do
      -- Record success in chain metrics
      atomically $ do
        m <- readTVar (cbMetrics chain)
        writeTVar
          (cbMetrics chain)
          m
            { chainTotalRequests = chainTotalRequests m + 1,
              chainLatencyMap = Map.insert (cbServiceName chain) [] (chainLatencyMap m)
            }
      return $ Right val
   where
     executeService :: CircuitBreakerFull -> IO a -> IO (Either Text a)
     executeService _breaker action = do
        result <- try action
        case result of
          Left err -> return $ Left (T.pack (show err))
          Right val -> return $ Right val

-- | Get chain execution report
generateChainReport :: CircuitBreakerChained -> IO String
generateChainReport chain = do
  metrics <- readTVarIO (cbMetrics chain)
  let services = cbServiceName chain : chainServiceOrder metrics
      report =
        unlines
          [ "Chain Execution Report",
            "Services: " ++ intercalate " -> " (map show services),
            "Total Requests: " ++ show (chainTotalRequests metrics),
            "Total Failures: " ++ show (chainTotalFailures metrics),
            "Failure Rate: " ++ show (fromIntegral (chainTotalFailures metrics) / max 1 (chainTotalRequests metrics))
          ]
  return report
