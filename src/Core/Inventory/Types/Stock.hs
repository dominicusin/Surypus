-- | Stock types - Current stock balances
module Core.Inventory.Types.Stock where

import Data.Int (Int64)
import Data.Text (Text)

-- | Stock - Current stock balance
data Stock = Stock
  { sGoodsId :: Int64,
    sLocationId :: Int64,
    sQtty :: Double,
    sResrvQtty :: Double,
    sOrderedQtty :: Double,
    sCost :: Double,
    sPrice :: Double
  }
  deriving (Show, Eq)

-- | Stock flags
data StockFlags = StockFlags
  { sfNegativeAllowed :: Bool,
    sfAutoReserve :: Bool
  }
  deriving (Show, Eq)

-- | Stock movement type
data StockMotionType
  = SMT_Receipt
  | SMT_Shipment
  | SMT_TransferIn
  | SMT_TransferOut
  | SMT_WriteOff
  | SMT_Adjustment
  deriving (Show, Eq, Enum)