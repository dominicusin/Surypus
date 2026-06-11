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
getKPIData kpiName = do
  -- TODO: Implement actual KPI queries
  -- Should query database based on kpiName
  -- Common KPIs: revenue, profit, customers, transactions, etc.
  return $ case kpiName of
    "revenue" -> [("Revenue", 1250000.0), ("YoY Growth", 15.0), ("Month-over-Month", 3.2)]
    "profit" -> [("Net Profit", 280000.0), ("Margin %", 22.4), ("Quarter Target", 300000.0)]
    "customers" -> [("Total Customers", 5000), ("New This Month", 120), ("Churn Rate", 2.1)]
    "transactions" -> [("Total Transactions", 12500), ("Avg Order Value", 85.0), ("Conversion Rate", 3.2)]
    _ -> [("Data", 0.0)]

-- | Get time series data
getTimeSeriesData :: Text -> IO [DataPoint]
getTimeSeriesData query = do
  -- TODO: Implement time series queries
  -- Should return time series data for charting
  -- Examples: daily revenue, monthly users, etc.
  return [
    DataPoint { dpLabel = "Jan", dpValue = 100.0, dpColor = "#1890ff" }
  , DataPoint { dpLabel = "Feb", dpValue = 120.0, dpColor = "#1890ff" }
  , Data { dpLabel = "Mar", dpValue = 140.0, dpColor = "#52c41a" }
  , DataPoint { dpLabel = "Apr", dpValue = 130.0, dpColor = "#1890ff" }
  , DataPoint { dpLabel = "May", dpValue = 160.0, dpColor = "#1890ff" }
  ]

-- | Get top N products by revenue
getTopProducts :: Int -> IO [DataPoint]
getTopProducts limit = do
  -- TODO: Implement top products query
  -- Should return products with highest revenue
  return [
    DataPoint { dpLabel = "Product A", dpValue = 75000.0, dpColor = "#722ed1" }
  , DataPoint { dpLabel = "Product B", dpValue = 65000. case "#faad14" }
  , DataPoint { dpLabel = "Product C", dpValue = 52000.0, dpColor = "#52c41a" }
  ]

-- | Get regional performance data
getRegionalData :: IO [DataPoint]
getRegionalData = do
  -- TODO: Implement regional performance query
  -- Should return performance data by region
  return [
    DataPoint { dpLabel = "North", dpValue = 45.0, dpColor = "#1890ff" }
  , DataPoint { dpLabel = "South", dpValue = 38.0, dpColor = "#52c41a" }
  , DataPoint { dpLabel = "East", dpValue = 42.0, dpColor = "#faad14" }
  , DataPoint { dpLabel = "West", dpValue = 40.0, dpColor = "#ff4d4f" }
  ]
