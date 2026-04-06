{-# LANGUAGE OverloadedStrings #-}

module Surypus.Metrics.Prometheus
  ( MetricsConfig (..),
    initMetrics,
    recordRequest,
    recordResponseTime,
    recordDatabaseQuery,
    recordError,
    renderMetrics,
    prometheusMetricsMiddleware,
    module Surypus.Metrics.Types,
  )
where

import Control.Concurrent (MVar, modifyMVar, newMVar)
import Control.Monad.IO.Class (liftIO)
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.Lazy as TL
import Data.Time (diffUTCTime, getCurrentTime)
import Network.Wai (Middleware, pathInfo, rawPathInfo, requestHeaders, requestMethod)
import qualified Network.Wai as Wai
import Surypus.Metrics.Types

initMetrics :: IO MetricsConfig
initMetrics = do
  requests <- newMVar mempty
  responseTimes <- newMVar mempty
  dbQueries <- newMVar mempty
  errors <- newMVar mempty
  activeRequests <- newMVar (0 :: Int)
  pure $
    MetricsConfig
      { mcRequests = requests,
        mcResponseTimes = responseTimes,
        mcDbQueries = dbQueries,
        mcErrors = errors,
        mcActiveRequests = activeRequests
      }

recordRequest :: MetricsConfig -> Text -> Text -> IO ()
recordRequest cfg method path = do
  modifyMVar_ (mcRequests cfg) $ \m ->
    let key = method <> " " <> path
        count = maybe 1 (+ 1) (lookup key m)
     in pure $! insert key count m

recordResponseTime :: MetricsConfig -> Text -> Double -> IO ()
recordResponseTime cfg path duration = do
  modifyMVar_ (mcResponseTimes cfg) $ \m ->
    let entry = maybe [duration] (duration :) (lookup path m)
        avg = sum entry / fromIntegral (length entry)
     in pure $! insert path avg m

recordDatabaseQuery :: MetricsConfig -> Text -> Double -> IO ()
recordDatabaseQuery cfg query duration = do
  modifyMVar_ (mcDbQueries cfg) $ \m ->
    let key = query
        entry = maybe [duration] (duration :) (lookup key m)
        avg = sum entry / fromIntegral (length entry)
     in pure $! insert key avg m

recordError :: MetricsConfig -> Text -> IO ()
recordError cfg errorType = do
  modifyMVar_ (mcErrors cfg) $ \m ->
    let count = maybe 1 (+ 1) (lookup errorType m)
     in pure $! insert errorType count m

incrementActiveRequests :: MetricsConfig -> IO ()
incrementActiveRequests cfg =
  modifyMVar_ (mcActiveRequests cfg) $ \n ->
    pure $! n + 1

decrementActiveRequests :: MetricsConfig -> IO ()
decrementActiveRequests cfg =
  modifyMVar_ (mcActiveRequests cfg) $ \n ->
    pure $! max 0 (n - 1)

getActiveRequests :: MetricsConfig -> IO Int
getActiveRequests cfg = readMVar (mcActiveRequests cfg)

renderMetrics :: MetricsConfig -> IO TL.Text
renderMetrics cfg = do
  requests <- readMVar (mcRequests cfg)
  responseTimes <- readMVar (mcResponseTimes cfg)
  dbQueries <- readMVar (mcDbQueries cfg)
  errors <- readMVar (mcErrors cfg)
  active <- getActiveRequests cfg

  let renderCounter name count =
        T.unlines
          [ "# HELP surypus_" <> name <> " Total " <> name,
            "# TYPE surypus_" <> name <> " counter",
            "surypus_" <> name <> " " <> T.pack (show count)
          ]

      renderHistogram name value =
        T.unlines
          [ "# HELP surypus_" <> name <> " Average " <> name,
            "# TYPE surypus_" <> name <> " gauge",
            "surypus_" <> name <> " " <> T.pack (show value)
          ]

      renderPathMetrics prefix m =
        T.unlines $
          fmap
            ( \(path, val) ->
                T.unlines
                  [ "# HELP surypus_" <> prefix <> "_" <> path <> " " <> prefix <> " for " <> path,
                    "# TYPE surypus_" <> prefix <> "_" <> path <> " gauge",
                    "surypus_" <> prefix <> "_" <> path <> " " <> T.pack (show val)
                  ]
            )
            (toList m)

  pure . TL.fromStrict $
    T.unlines
      [ "# Surypus ERP Prometheus Metrics",
        "",
        renderCounter "http_requests_total" (sum . fmap snd $ toList requests),
        renderHistogram "http_active_requests" active,
        "",
        "# HTTP Response Times",
        renderPathMetrics "http_response_time_seconds" responseTimes,
        "",
        "# Database Query Times",
        renderPathMetrics "db_query_time_seconds" dbQueries,
        "",
        "# Error Counts",
        renderCounter "errors_total" (sum . fmap snd $ toList errors)
      ]

prometheusMetricsMiddleware :: MetricsConfig -> Middleware
prometheusMetricsMiddleware cfg app req respond = do
  start <- liftIO getCurrentTime
  incrementActiveRequests cfg
  app req $ \res -> do
    end <- liftIO getCurrentTime
    let duration = diffUTCTime end start
        method = T.decodeUtf8 $ requestMethod req
        path = T.decodeUtf8 $ rawPathInfo req
    liftIO $ do
      recordRequest cfg method path
      recordResponseTime cfg path (realToFrac duration)
      decrementActiveRequests cfg
    respond res

-- | Insert a key-value pair into a map, updating existing values
insert :: (Ord k) => k -> v -> Map k v -> Map k v
insert k v = Map.insert k v
