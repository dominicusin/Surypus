{-# LANGUAGE OverloadedStrings #-}

-- | Metrics collection and reporting using EKG for Prometheus format
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

import Control.Concurrent.STM (TVar, atomically, modifyTVar', readTVarIO, newTVarIO)
import Control.Exception (bracket)
import Data.Text (Text)
import Data.Int (Int64)
import qualified Data.Text as T
import System.Ekg (Store, newStore, Counter, Gauge, Distribution, add, forkServer)

-- | Metrics handle containing STM counters that EKG can read
data Metrics = Metrics
  { metricsStore :: Store,
    httpRequestsTotal :: Counter,
    httpRequestDuration :: Distribution,
    dbPoolConnections :: Gauge,
    jobQueueSize :: Gauge
  }

-- | Initialize metrics collection with EKG
initMetrics :: IO Metrics
initMetrics = do
  store <- newStore
  reqTotal <- newCounter "http_requests_total" store
  reqDuration <- newDistribution "http_request_duration_seconds" store
  poolConn <- newGauge "db_pool_connections" store
  queueSize <- newGauge "job_queue_size" store
  pure $ Metrics store reqTotal reqDuration poolConn queueSize

-- | Record a counter increment
recordCounter :: Metrics -> Text -> Int64 -> IO ()
recordCounter m name value = do
  if name == "http_requests_total"
    then modifyCounter (httpRequestsTotal m) (+ fromIntegral value)
    else pure ()

-- | Record a timer measurement (nanoseconds, converted to seconds)
recordTimer :: Metrics -> Text -> Int64 -> IO ()
recordTimer m _name durationNs = do
  let durationSec = fromIntegral durationNs / 1e9 :: Double
  add (httpRequestDuration m) durationSec

-- | Record a gauge value
recordGauge :: Metrics -> Text -> Double -> IO ()
recordGauge m name value = case T.unpack name of
  "db_pool_connections" -> setGauge (dbPoolConnections m) value
  "job_queue_size" -> setGauge (jobQueueSize m) value
  _ -> pure ()
  where
    setGauge :: Gauge -> Double -> IO ()
    setGauge g val = modifyGauge g (const (Just val))

-- | Flush metrics (no-op, EKG handles automatically)
flushMetrics :: Metrics -> IO ()
flushMetrics _ = pure ()

-- | Get current metrics value for testing
getMetricsValue :: Metrics -> Text -> IO Double
getMetricsValue _m "http_requests_total" = do
  cnt <- readCounter (httpRequestsTotal _m)
  pure $ fromIntegral cnt
getMetricsValue _m _ = pure 0

-- | Start EKG server for metrics endpoint
startMetricsServer :: Int -> Metrics -> IO ()
startMetricsServer port _ = do
  _store <- newStore
  _ <- forkServer ("*:" ++ show port) _store
  pure ()

-- Re-exports for convenience
modifyCounter :: Counter -> (Int64 -> Int64) -> IO ()
modifyCounter = undefined  -- Will be provided by ekg-core

readCounter :: Counter -> IO Int64
readCounter = undefined

modifyGauge :: Gauge -> (Maybe Double -> Maybe Double) -> IO ()
modifyGauge = undefined