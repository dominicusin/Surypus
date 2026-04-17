-- | AdvanceBill module - Advance bills
module Core.AdvanceBill where

import Data.Int (Int64)
import Data.Time (Day)

-- | AdvanceBill - Advance bill
data AdvanceBill = AdvanceBill
  { abId :: Int64,
    abNumber :: String,
    abDate :: Day,
    abCustomerId :: Int64,
    abAmount :: Double,
    abTaxAmount :: Double
  }
  deriving (Show, Eq)

-- | Get total
getTotal :: AdvanceBill -> Double
getTotal ab = abAmount ab + abTaxAmount ab
