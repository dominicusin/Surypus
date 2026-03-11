-- | Analytics module - Reporting and BI
module Core.Analytics where

import           Data.Int  (Int64)
import           Data.Text (Text)
import           Data.Time (Day)

-- | TimeSeries - Time series data
data TimeSeries = TimeSeries
  { tsId     :: Int64
  , tsName   :: Text
  , tsPeriod :: Period
  , tsFlags  :: Int
  } deriving (Show, Eq)

data Period = P_Day | P_Week | P_Month | P_Quarter | P_Year
  deriving (Show, Eq)

-- | BizScore - Business score
data BizScore = BizScore
  { bsId      :: Int64
  , bsName    :: Text
  , bsFormula :: Text
  , bsValue   :: Double
  , bsDate    :: Day
  } deriving (Show, Eq)

-- | Sales analytics
data SalesAnalytics = SalesAnalytics
  { saGoodsId    :: Int64
  , saLocationId :: Int64
  , saPeriod     :: Day
  , saQty        :: Double
  , saAmount     :: Double
  , saCost       :: Double
  } deriving (Show, Eq)

-- | Calculate profit
calcProfit :: SalesAnalytics -> Double
calcProfit sa = saAmount sa - saCost sa

-- | Calculate margin %
calcMargin :: SalesAnalytics -> Double
calcMargin sa
  | saAmount sa == 0 = 0
  | otherwise = (calcProfit sa / saAmount sa) * 100
