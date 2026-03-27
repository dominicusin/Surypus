-- | BillLine module - Bill lines
module Core.BillLine where

import Data.Int (Int64)

-- | BillLine - Bill line item
data BillLine = BillLine
  { blId :: Int64,
    blBillId :: Int64,
    blGoodsId :: Int64,
    blQtty :: Double,
    blPrice :: Double,
    blDiscount :: Double,
    blTaxRate :: Double,
    blFlags :: Int
  }
  deriving (Show, Eq)

-- | Calculate line total
calcLineTotal :: BillLine -> Double
calcLineTotal bl = blQtty bl * blPrice bl * (1 - blDiscount bl / 100)
