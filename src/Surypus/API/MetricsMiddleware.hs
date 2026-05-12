{-# LANGUAGE OverloadedStrings #-}
module Surypus.API.MetricsMiddleware
  ( MetricsMiddlewareConfig (..),
    withMetricsCollection,
  )
where

import Data.Text (Text)
import Network.Wai (Application)
import Surypus.Metrics (Metrics)

data MetricsMiddlewareConfig = MetricsMiddlewareConfig
  { mmcMetrics :: Metrics,
    mmcPublicPaths :: [Text]
  }

withMetricsCollection :: MetricsMiddlewareConfig -> Application -> Application
withMetricsCollection _cfg app = app
