-- | Metrics collection and reporting
module Surypus.Metrics
  ( Metrics,
    initMetrics,
    recordCounter,
    recordTimer,
    recordGauge,
  )
where

import Data.Text (Text)
import Data.Int (Int64)

-- | Metrics handle (opaque)
data Metrics = Metrics
  deriving (Show, Eq)

-- | Initialize metrics collection
initMetrics :: IO Metrics
initMetrics = pure Metrics

-- | Record a counter increment
recordCounter :: Metrics -> Text -> Int64 -> IO ()
recordCounter _metrics _name _value = pure ()

-- | Record a timer measurement (nanoseconds)
recordTimer :: Metrics -> Text -> Int64 -> IO ()
recordTimer _metrics _name _duration = pure ()

-- | Record a gauge value
recordGauge :: Metrics -> Text -> Double -> IO ()
recordGauge _metrics _name _value = pure ()