{-# LANGUAGE OverloadedStrings #-}

-- | Metrics collection and reporting (stub for compilation)
module Surypus.Metrics
  ( Metrics,
    initMetrics,
    recordCounter,
    recordTimer,
    recordGauge,
    httpRequestsTotal,
    httpRequestDuration,
    dbPoolConnections,
    jobQueueSize,
    flushMetrics,
    getMetricsValue,
    startMetricsServer,
  )
where

import Control.Concurrent.STM (TVar, atomically, newTVarIO, readTVarIO, modifyTVar')
import Data.Text (Text)
import Data.Int (Int64)

-- | Simple counter type
newtype Counter = Counter (TVar Int64)

-- | Simple gauge type
newtype Gauge = Gauge (TVar Double)

-- | Simple distribution/histogram type  
newtype Distribution = Distribution (TVar Double)

-- | Metrics handle containing STM counters
data Metrics = Metrics
  { httpRequestsTotal :: Counter
  , httpRequestDuration :: Distribution
  , dbPoolConnections :: Gauge
  , jobQueueSize :: Gauge
  }

-- | Initialize metrics collection
initMetrics :: IO Metrics
initMetrics = do
  reqTotal <- Counter <$> newTVarIO 0
  reqDuration <- Distribution <$> newTVarIO 0
  poolConn <- Gauge <$> newTVarIO 0
  queueSz <- Gauge <$> newTVarIO 0
  pure $ Metrics reqTotal reqDuration poolConn queueSz

-- | Record a counter increment
recordCounter :: Metrics -> Text -> Int64 -> IO ()
recordCounter _ _ _ = pure ()

-- | Record a timer measurement (nanoseconds, converted to seconds)
recordTimer :: Metrics -> Text -> Int64 -> IO ()
recordTimer _ _ _ = pure ()

-- | Record a gauge value
recordGauge :: Metrics -> Text -> Double -> IO ()
recordGauge _ _ _ = pure ()

-- | Flush metrics (no-op, EKG handles automatically)
flushMetrics :: Metrics -> IO ()
flushMetrics _ = pure ()

-- | Get current metrics value for testing
getMetricsValue :: Metrics -> Text -> IO Double
getMetricsValue _ _ = pure 0

-- | Start EKG server for metrics endpoint
startMetricsServer :: Int -> Metrics -> IO ()
startMetricsServer _ _ = pure ()