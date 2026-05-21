-- | Analytics module - Reporting and BI
module Analytics.Analytics
  ( TimeSeries   (..),
    Period   (..),
    BizScore   (..),
    SalesAnalytics   (..),
    calcProfit,
    calcMargin,
    prop_profitBounded,
    prop_marginBounded
  ) where

import Data.Int (Int64)
import Data.Text (Text)
import Data.Time (Day, fromGregorian)
import Test.QuickCheck

{-@ type NonNeg = {v:Double | v >= 0} @-}

-- | TimeSeries - Time series data
data TimeSeries = TimeSeries
  { tsId :: Int64,
    tsName :: Text,
    tsPeriod :: Period,
    tsFlags :: Int
  }
  deriving (Show, Eq)

data Period = PDay | PWeek | PMonth | PQuarter | PYear
  deriving (Show, Eq)

-- | BizScore - Business score
data BizScore = BizScore
  { bsId :: Int64,
    bsName :: Text,
    bsFormula :: Text,
    bsValue :: Double,
    bsDate :: Day
  }
  deriving (Show, Eq)

-- | Sales analytics
data SalesAnalytics = SalesAnalytics
  { saGoodsId :: Int64,
    saLocationId :: Int64,
    saPeriod :: Day,
    saQty :: Double,
    saAmount :: Double,
    saCost :: Double
  }
  deriving (Show, Eq)

-- | Calculate profit
calcProfit :: SalesAnalytics -> Double
calcProfit sa = saAmount sa - saCost sa

-- | Calculate margin %
calcMargin :: SalesAnalytics -> Double
calcMargin sa
  | saAmount sa == 0 = 0
  | otherwise = (calcProfit sa / saAmount sa) * 100

-- ============================================================================
-- QUICKCHECK PROPERTIES
-- ============================================================================

instance Arbitrary SalesAnalytics where
  arbitrary = do
    qty <- suchThat arbitrary (>= 0)
    amount <- suchThat arbitrary (>= 0)
    cost <- choose (0, amount)
    pure $ SalesAnalytics 0 0 (fromGregorian 2024 1 1) qty amount cost

prop_profitBounded :: SalesAnalytics -> Property
prop_profitBounded sa =
  let amount = saAmount sa
      cost = saCost sa
   in amount >= 0 && cost >= 0 && cost <= amount ==> calcProfit sa >= 0

prop_marginBounded :: SalesAnalytics -> Property
prop_marginBounded sa =
  let amount = saAmount sa
   in amount > 0 ==> calcMargin sa >= 0 && calcMargin sa <= 100
