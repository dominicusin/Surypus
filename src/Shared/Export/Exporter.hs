module Shared.Export.Exporter where
  ( startPrometheusExport,
    pushMetrics,
  )
where

import Control.Concurrent.STM
import Control.Concurrent.STM.TVar
import Data.Text (Text)
import qualified Data.Text as T

-- | Placeholder for starting a Prometheus exporter using ekg/prometheus-haskell
startPrometheusExport :: IO ()
startPrometheusExport = putStrLn "Prometheus exporter initialized (placeholder)"

-- | Push a text metric line (placeholder)
pushMetrics :: Text -> IO ()
pushMetrics t = putStrLn $ "metric: " <> T.unpack t
