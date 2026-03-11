-- | WarehouseOps module - Warehouse operations
module Core.WarehouseOps where

import           Data.Int  (Int64)
import           Data.Text (Text)

-- | WarehouseOps - Warehouse operation
data WarehouseOps = WarehouseOps
  { woId        :: Int64
  , woType      :: WarehouseOpType
  , woGoodsId   :: Int64
  , woFromLocId :: Maybe Int64
  , woToLocId   :: Maybe Int64
  , woQtty      :: Double
  , woStatus    :: OpStatus
  } deriving (Show, Eq)

data WarehouseOpType = WOT_Pick | WOT_Pack | WOT_Ship | WOT_Receive | WOT_Returns
  deriving (Show, Eq)

data OpStatus = OPS_Pending | OPS_InProgress | OPS_Completed | OPS_Cancelled
  deriving (Show, Eq)
