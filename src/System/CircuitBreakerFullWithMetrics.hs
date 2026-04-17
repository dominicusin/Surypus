module System.CircuitBreakerFullWithMetrics where

import Control.Concurrent.STM (TVar, newTVarIO)

data CircuitBreakerFullWithMetrics = CircuitBreakerFullWithMetrics
  { cbStateVar :: TVar CBState
  }

data CBState
  = CBSClosed
  | CBSOpen
  | CBSHalfOpen
  | CBSDisabled
  deriving (Show, Eq)

data CircuitConfig = CircuitConfig
  { failureThresholdCount :: Int,
    resetTimeoutSec :: Int
  }

initCircuitBreakerFullWithMetrics :: CircuitConfig -> IO CircuitBreakerFullWithMetrics
initCircuitBreakerFullWithMetrics _ = do
  stateVar <- newTVarIO CBSClosed
  return $ CircuitBreakerFullWithMetrics {cbStateVar = stateVar}
