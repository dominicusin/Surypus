module Surypus.Metrics.Types
  ( MetricsConfig (..),
    CounterMap,
    GaugeMap,
    HistogramMap,
  )
where

import Data.Map (Map)
import Data.Text (Text)

type CounterMap = Map Text Int

type GaugeMap = Map Text Double

type HistogramMap = Map Text [Double]

data MetricsConfig = MetricsConfig
  { mcRequests :: !(IO (Map Text Int)),
    mcResponseTimes :: !(IO (Map Text Double)),
    mcDbQueries :: !(IO (Map Text Double)),
    mcErrors :: !(IO (Map Text Int)),
    mcActiveRequests :: !(IO Int)
  }
