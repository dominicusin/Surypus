-- | Lot types - Stock lots/batches
module Core.Inventory.Types.Lot where

import Data.Int (Int64)
import Data.Text (Text)
import Data.Time (Day)

-- | Lot - Stock lot (партия товара)
data Lot = Lot
  { lotId :: Int64,
    lotGoodsId :: Int64,
    lotLocationId :: Int64,
    lotQtty :: Double,
    lotCost :: Double,
    lotPrice :: Double,
    lotDate :: Day,
    lotExpiry :: Maybe Day,
    lotFlags :: Int,
    lotSerialNumber :: Maybe Text,
    lotSupplierId :: Maybe Int64,
    lotBillId :: Maybe Int64
  }
  deriving (Show, Eq)

-- | Lot status
data LotStatus
  = LS_Active
  | LS_Closed
  | LS_Expired
  | LS_Reserved
  deriving (Show, Eq)

-- | Lot flags
data LotFlags = LotFlags
  { lfStrictSerial :: Bool,
    lfNegativeOk :: Bool,
    lfFifo :: Bool
  }
  deriving (Show, Eq)