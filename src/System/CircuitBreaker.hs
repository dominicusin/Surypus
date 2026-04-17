module System.CircuitBreaker where

import Control.Concurrent.STM (TVar, atomicModifyTVar, newTVarIO, readTVar, writeTVar)
import Data.List (partition)
import Data.Time.Clock (UTCTime, addUTCTime, getCurrentTime)

-- | Circuit breaker state
data CircuitState
  = Closed
  | Open
  | HalfOpen
  deriving (Show, Eq)

-- | Circuit breaker configuration
data CircuitConfig = CircuitConfig
  { maxFailures :: Int,
    resetTimeout :: Int,
    halfOpenMaxCalls :: Int
  }

-- | Circuit breaker state with metrics
data CircuitBreaker = CircuitBreaker
  { cbState :: TVar CircuitState,
    cbFailures :: TVar Int,
    cbLastFailure :: TVar (Maybe UTCTime),
    cbCalls :: TVar (Int, Int), -- (successes, total)
    cbConfig :: CircuitConfig
  }

-- | Initialize circuit breaker
initCircuitBreaker :: CircuitConfig -> IO CircuitBreaker
initCircuitBreaker config = do
  state <- newTVarIO Closed
  failures <- newTVarIO 0
  lastFail <- newTVarIO Nothing
  calls <- newTVarIO (0, 0)
  return $ CircuitBreaker state failures lastFail calls config

-- | Execute an action through the circuit breaker
circuitBreakerAction :: CircuitBreaker -> IO a -> IO (Either Text a)
circuitBreakerAction breaker action = do
  state <- readTVarIO (cbState breaker)
  case state of
    Open -> do
      lastFailTime <- readTVarIO (cbLastFailure breaker)
      config <- readTVarIO (cbConfig breaker)
      now <- getCurrentTime
      case lastFailTime of
        Nothing -> return $ Left "Circuit is open"
        Just t ->
          if diffUTCTime now t >= fromIntegral (resetTimeout config)
            then tryHalfOpen breaker action
            else return $ Left "Circuit is open"
    HalfOpen -> do
      (successes, total) <- readTVarIO (cbCalls breaker)
      if successes >= halfOpenMaxCalls (cbConfig breaker)
        then do
          writeTVarIO (cbState breaker) Closed
          writeTVarIO (cbFailures breaker) 0
          executeAction breaker action
        else return $ Left "Circuit is half-open, not enough successes"
    Closed -> executeAction breaker action

-- | Execute action in closed state
executeAction :: CircuitBreaker -> IO a -> IO (Either Text a)
executeAction breaker action = do
  result <- try action
  case result of
    Right val -> do
      atomicModifyTVar' (cbCalls breaker) $ \(s, t) -> ((s + 1, t + 1), ())
      return $ Right val
    Left err -> do
      handleFailure breaker
      return $ Left err

-- | Handle failure - update state accordingly
handleFailure :: CircuitBreaker -> IO ()
handleFailure breaker = do
  atomicModifyTVar' (cbFailures breaker) $ \f -> ((f + 1, f + 1), ())
  failures <- readTVarIO (cbFailures breaker)
  config <- readTVarIO (cbConfig breaker)
  now <- getCurrentTime
  writeTVarIO (cbLastFailure breaker) (Just now)
  if failures >= maxFailures config
    then writeTVarIO (cbState breaker) Open
    else writeTVarIO (cbState breaker) Closed

-- | Try an action catching exceptions
try :: IO a -> IO (Either Text a)
try action =
  catch
    ( do
        val <- action
        return $ Right val
    )
    (\e -> return $ Left (T.pack (show (e :: SomeException))))

-- | Get current failure count
getFailureCount :: CircuitBreaker -> IO Int
getFailureCount = readTVarIO . cbFailures

-- | Get current success rate
getSuccessRate :: CircuitBreaker -> IO (Maybe Double)
getSuccessRate breaker = do
  (successes, total) <- readTVarIO (cbCalls breaker)
  if total > 0
    then return $ Just (fromIntegral successes / fromIntegral total)
    else return Nothing
