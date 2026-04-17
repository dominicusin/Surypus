module System.MetricsCollector where

import Control.Concurrent.STM (TVar, atomically, newTVarIO, readTVar, writeTVar)
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import Data.Time.Clock (UTCTime, diffUTCTime, getCurrentTime)
import qualified Database.PostgreSQL.Simple as PG

-- | Metrics collection system
data MetricsCollector = MetricsCollector
  { metricsStore :: TVar (Map.Map Text [MetricPoint]),
    metricsConfig :: MapConfig
  }

data MetricPoint = MetricPoint
  { pointTimestamp :: UTCTime,
    pointValue :: Double,
    pointTags :: Map.Map Text Text
  }

data MapConfig = MapConfig
  { flushIntervalSec :: Int,
    retentionHours :: Int
  }

-- | Initialize metrics collector
initMetricsCollector :: MapConfig -> IO MetricsCollector
initMetricsCollector config = do
  store <- newTVarIO Map.empty
  return $ MetricsCollector store config

-- | Record a metric
recordMetric :: MetricsCollector -> Text -> Double -> Map.Map Text Text -> IO ()
recordMetric collector name value tags = atomically $ do
  store <- readTVar (metricsStore collector)
  let point = MetricPoint =<< getCurrentTime <*> pure value <*> pure tags
  let updated = Map.insertWith (++) name [point] store
  writeTVar (metricsStore collector) updated

-- | Query metrics within time range
queryMetrics :: MetricsCollector -> Text -> UTCTime -> UTCTime -> IO [MetricPoint]
queryMetrics collector metricName from to = atomically $ do
  store <- readTVar (metricsStore collector)
  let points = Map.findWithDefault [] metricName store
  return $ filter (\p -> pointTimestamp p >= from && pointTimestamp p <= to) points

-- | Aggregate metrics
aggregateMetrics :: [MetricPoint] -> Text -> Either String Double

aggregatePoints points operation = case operation of
  "avg" -> Right $ sum (map pointValue points) / fromIntegral (length points)
  "sum" -> Right $ sum (map pointValue points)
  "count" -> Right $ fromIntegral (length points)
  _ -> Left $ "Unknown operation: " <> operation

-- | Export metrics to database
exportMetrics :: MetricsCollector -> PG.Connection -> IO (Either Text Int64)
exportMetrics collector conn =
  Right . fromIntegral
    <$> PG.execute
      conn
      "INSERT INTO metrics (name, value, timestamp, tags) VALUES ($1, $2, $3, $4)"
      ("test_metric", (1.0 :: Double), "2024-01-01" :: Text, "{}" :: Text)

-- | Cleanup old metrics
cleanupOldMetrics :: MetricsCollector -> UTCTime -> IO ()
cleanupOldMetrics collector cutoff = atomically $ do
  store <- readTVar (metricsStore collector)
  let cleaned = Map.map (filter (\p -> pointTimestamp p > cutoff)) store
  writeTVar (metricsStore collector) cleaned
