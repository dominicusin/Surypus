-- | Stock types - Current stock balances
module Inventory.Stock
  ( Stock(..)
  , StockFlags(..)
  , StockMotionType(..)
  , mkStock
  , validateStock
  ) where

import Data.Int (Int64)

-- | Stock - Current stock balance
-- Invariant: quantity cannot be negative unless negativeAllowed flag is set
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

-- | Smart constructor for Stock that validates invariants
-- Returns Nothing if quantity is negative and negativeAllowed is false
mkStock :: Int64 -> Int64 -> Double -> Double -> Double -> Double -> Double -> StockFlags -> Maybe Stock
mkStock goodsId locId qtty resrv ordered cost price flags
  | qtty < 0 && not (sfNegativeAllowed flags) = Nothing
  | resrv < 0 = Nothing
  | ordered < 0 = Nothing
  | cost < 0 = Nothing
  | price < 0 = Nothing
  | otherwise = Just $ Stock goodsId locId qtty resrv ordered cost price

-- | Validate stock invariants
validateStock :: Stock -> StockFlags -> Bool
validateStock stock flags =
  (sQtty stock >= 0 || sfNegativeAllowed flags) &&
  sResrvQtty stock >= 0 &&
  sOrderedQtty stock >= 0 &&
  sCost stock >= 0 &&
  sPrice stock >= 0

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
