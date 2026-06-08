{-# LANGUAGE OverloadedStrings #-}
module Analytics.Dashboard where

import Data.Text (Text)
import Data.Int (Int64)

-- | Dashboard widget type
data WidgetType = KPI | Chart | Table | Metric deriving (Eq, Show)

-- | Dashboard widget configuration
data Widget = Widget
  { wId :: Int64
  , wType :: WidgetType
  , wTitle :: Text
  , wQuery :: Text
  , wPosition :: (Int, Int)
  , wSize :: (Int, Int)
  } deriving (Eq, Show)

-- | Dashboard data point
data DataPoint = DataPoint
  { dpLabel :: Text
  , dpValue :: Double
  , dpColor :: Text
  } deriving (Eq, Show)

-- | Get KPI data
getKPIData :: Text -> IO [(Text, Double)]
getKPIData _kpiName = do
  -- TODO: Implement actual KPI queries
  return [("placeholder", 0.0)]

-- | Get time series data
getTimeSeriesData :: Text -> IO [DataPoint]
getTimeSeriesData query = do
  -- TODO: Implement time series queries
  return []
