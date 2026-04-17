module System.RateLimiterAdvanced where

import Control.Concurrent.STM (TVar, atomically, newTVarIO, readTVar, writeTVar)
import qualified Data.Sequence as Seq
import Data.Time.Clock (UTCTime, diffUTCTime, getCurrentTime)

-- | Advanced rate limiter with multiple strategies
data RateLimiterAdvanced = RateLimiterAdvanced
  { limiterConfig :: RateConfig,
    limiterState :: TVar LimiterState,
    limiterMetrics :: TVar RateMetrics
  }

-- | Rate limiting strategies
data RateStrategy
  = TokenBucket
  | LeakyBucket
  | FixedWindow
  | SlidingWindow
  deriving (Show, Eq)

-- | Rate configuration
data RateConfig = RateConfig
  { rateStrategy :: RateStrategy,
    rateLimit :: Double,
    rateWindowSec :: Int,
    rateBurst :: Int,
    ratePenalty :: Double
  }

-- | Limiter state by strategy
data LimiterState
  = TokenState {tokens :: Double, lastRefill :: UTCTime}
  | LeakState {leaks :: Seq.Seq UTCTime}
  | WindowState {windowCounts :: [(UTCTime, Int)]}
  | SlidingState {slidingRequests :: Seq.Seq UTCTime}
  deriving (Show)

-- | Rate metrics
data RateMetrics = RateMetrics
  { totalRequests :: Int,
    totalAllowed :: Int,
    totalDenied :: Int,
    currentRate :: Double,
    penaltyApplied :: Int
  }

-- | Initialize advanced rate limiter
initRateLimiterAdvanced :: RateConfig -> IO RateLimiterAdvanced
initRateLimiterAdvanced config = do
  state <- newTVarIO $ initState (rateStrategy config)
  metricsVar <-
    newTVarIO
      RateMetrics
        { totalRequests = 0,
          totalAllowed = 0,
          totalDenied = 0,
          currentRate = 0,
          penaltyApplied = 0
        }
  return $ RateLimiterAdvanced config state metricsVar
  where
    initState TokenBucket = TokenState 0 =<< getCurrentTime
    initState LeakyBucket = LeakState Seq.empty
    initState FixedWindow = WindowState []
    initState SlidingWindow = SlidingState Seq.empty

-- | Check request with advanced logic
checkRequestAdvanced :: RateLimiterAdvanced -> IO Bool
checkRequestAdvanced limiter = do
  now <- getCurrentTime
  atomically $ do
    state <- readTVar (limiterState limiter)
    (allowed, newState) <- evaluateStrategy limiter state now
    writeTVar (limiterState limiter) newState
    updateMetrics limiter now allowed
    return allowed
  where
    evaluateStrategy _ (TokenState tokens lastRefill) now =
      let refillRate = rateLimit (limiterConfig limiter)
          elapsed = realToFrac $ diffUTCTime now lastRefill
          newTokens = min (rateLimit (limiterConfig limiter)) (tokens + elapsed * refillRate)
       in if newTokens >= 1
            then (True, TokenState (newTokens - 1) now)
            else (False, TokenState newTokens now)
    evaluateStrategy _ (LeakState leaks) now =
      let windowSize = fromIntegral (rateWindowSec limiter)
          validLeaks = Seq.dropWhileL (\t -> diffUTCTime now t < windowSize) leaks
          count = Seq.length validLeaks
       in if count < rateLimit (limiterConfig limiter)
            then (True, LeakState (validLeaks Seq.|> now))
            else (False, LeakState validLeaks)
    evaluateStrategy _ (WindowState counts) now =
      let windowStart = diffUTCTime now (fromIntegral (rateWindowSec limiter) * 60)
          validCounts = filter (\(t, _) -> t > windowStart) counts
          total = sum (map snd validCounts)
       in if total < rateLimit (limiterConfig limiter)
            then (True, WindowState ((now, 1) : validCounts))
            else (False, WindowState ((now, 1) : validCounts))
    evaluateStrategy _ (SlidingState reqs) now =
      let windowStart = diffUTCTime now (fromIntegral (rateWindowSec limiter) * 60)
          validReqs = Seq.dropWhileL (\t -> diffUTCTime now t < windowStart) reqs
       in if Seq.length validReqs < rateLimit (limiterConfig limiter)
            then (True, SlidingState (validReqs Seq.|> now))
            else (False, SlidingState validReqs)

-- | Check with burst allowance
checkRequestWithBurst :: RateLimiterAdvanced -> IO Bool
checkRequestWithBurst limiter = do
  allowed <- checkRequestAdvanced limiter
  if not allowed
    then do
      -- Apply penalty
      atomically $ do
        m <- readTVar (limiterMetrics limiter)
        writeTVar
          (limiterMetrics limiter)
          m
            { penaltyApplied = penaltyApplied m + 1,
              currentRate = currentRate m * ratePenalty (limiterConfig limiter)
            }
      return False
    else return True

-- | Get current rate
getRateAdvanced :: RateLimiterAdvanced -> IO Double
getRateAdvanced limiter = readTVarIO (limiterMetrics limiter) >>= return . currentRate

-- | Reset limiter
resetRateLimiterAdvanced :: RateLimiterAdvanced -> IO ()
resetRateLimiterAdvanced limiter = atomically $ do
  state <- readTVar (limiterState limiter)
  now <- getCurrentTime
  let newState = initState (rateStrategy limiter)
  writeTVar (limiterState limiter) newState
  m <- readTVar (limiterMetrics limiter)
  writeTVar
    (limiterMetrics limiter)
    m
      { totalRequests = 0,
        totalAllowed = 0,
        totalDenied = 0,
        currentRate = 0,
        penaltyApplied = 0
      }
  where
    initState TokenBucket = TokenState 0 now
    initState LeakyBucket = LeakState Seq.empty
    initState FixedWindow = WindowState []
    initState SlidingWindow = SlidingState Seq.empty
