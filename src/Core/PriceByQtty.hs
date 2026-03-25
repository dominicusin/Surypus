-- | PriceByQtty module - Quantity-based pricing
module Core.PriceByQtty where

import Data.Int (Int64)

-- | PriceByQtty - Quantity-based price
data PriceByQtty = PriceByQtty
  { pbqId :: Int64,
    pbqGoodsId :: Int64,
    pbqPrice :: Double,
    pbqMinQtty :: Double,
    pbqMaxQtty :: Double
  }
  deriving (Show, Eq)

-- | Get price
getQttyPrice :: PriceByQtty -> Double
getQttyPrice = pbqPrice
