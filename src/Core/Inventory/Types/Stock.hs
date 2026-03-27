-- | Stock types - Current stock balances
module Core.Inventory.Types.Stock where

import Data.Int (Int64)

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
  = SMTReceipt
  | SMTShipment
  | SMTTransferIn
  | SMTTransferOut
  | SMTWriteOff
  | SMTAdjustment
  deriving (Show, Eq, Enum)
