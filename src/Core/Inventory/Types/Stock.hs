-- | Stock types - Current stock balances
module Core.Inventory.Types.Stock where

import Core.Refined (NonNegDouble)
import Data.Int (Int64)
import Data.Text (Text)

-- | Stock - Current stock balance
{-@ data Stock = Stock
  { sGoodsId :: Int64,
    sLocationId :: Int64,
    sQtty :: NonNegDouble,
    sResrvQtty :: NonNegDouble,
    sOrderedQtty :: NonNegDouble,
    sCost :: NonNegDouble,
    sPrice :: NonNegDouble
  } @-}
data Stock = Stock
  { sGoodsId :: Int64,
    sLocationId :: Int64,
    sQtty :: Double, -- Current quantity
    sResrvQtty :: Double, -- Reserved quantity
    sOrderedQtty :: Double, -- Ordered quantity
    sCost :: Double, -- Average cost
    sPrice :: Double -- Retail price
  }
  deriving (Show, Eq)

-- | Stock flags
data StockFlags = StockFlags
  { sfNegativeAllowed :: Bool, -- Allow negative stock
    sfAutoReserve :: Bool -- Auto-reserve on sale
  }
  deriving (Show, Eq)

-- | Stock movement type
data StockMotionType
  = SMT_Receipt -- Receipt (Поступление)
  | SMT_Shipment -- Shipment (Реализация)
  | SMT_TransferIn -- Transfer in (Перемещение +)
  | SMT_TransferOut -- Transfer out (Перемещение -)
  | SMT_WriteOff -- Write-off (Списание)
  | SMT_Adjustment -- Adjustment (Корректировка)
  deriving (Show, Eq, Enum)
