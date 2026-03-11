-- | Lot types - Stock lots/batches
module Core.Inventory.Types.Lot where

import Core.Refined (NonNegDouble)
import Data.Int (Int64)
import Data.Text (Text)
import Data.Time (Day)

-- | Lot - Stock lot (партия товара)
{-@ data Lot = Lot
  { lotId :: Int64,
    lotGoodsId :: Int64,
    lotLocationId :: Int64,
    lotQtty :: NonNegDouble,
    lotCost :: NonNegDouble,
    lotPrice :: NonNegDouble,
    lotDate :: Day,
    lotExpiry :: Maybe Day,
    lotFlags :: Int,
    lotSerialNumber :: Maybe Text,
    lotSupplierId :: Maybe Int64,
    lotBillId :: Maybe Int64
  } @-}
data Lot = Lot
  { lotId :: Int64,
    lotGoodsId :: Int64,
    lotLocationId :: Int64,
    lotQtty :: Double, -- Quantity in lot
    lotCost :: Double, -- Cost price
    lotPrice :: Double, -- Sale price
    lotDate :: Day, -- Receipt date
    lotExpiry :: Maybe Day, -- Expiry date
    lotFlags :: Int,
    lotSerialNumber :: Maybe Text,
    lotSupplierId :: Maybe Int64,
    lotBillId :: Maybe Int64
  }
  deriving (Show, Eq)

-- | Lot status
data LotStatus
  = LS_Active -- Active (действующая)
  | LS_Closed -- Closed (закрыта)
  | LS_Expired -- Expired (просрочена)
  | LS_Reserved -- Reserved (зарезервирована)
  deriving (Show, Eq)

-- | Lot flags - corresponds to LOTF_*
data LotFlags = LotFlags
  { lfStrictSerial :: Bool, -- LOTF_STRICTSERIAL (строгий учет серий)
    lfNegativeOk :: Bool, -- LOTF_NEGATIVE (разрешен отрицательный остаток)
    lfFifo :: Bool -- LOTF_FIFO (FIFO списание)
  }
  deriving (Show, Eq)
