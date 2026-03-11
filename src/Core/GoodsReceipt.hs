-- | GoodsReceipt module - Goods receipt
module Core.GoodsReceipt where

import           Data.Int  (Int64)
import           Data.Time (Day)

-- | GoodsReceipt - Goods receipt
data GoodsReceipt = GoodsReceipt
  { grId          :: Int64
  , grNumber      :: String
  , grDate        :: Day
  , grSupplierId  :: Int64
  , grWarehouseId :: Int64
  , grStatus      :: ReceiptStatus
  } deriving (Show, Eq)

data ReceiptStatus = RS_Pending | RS_Received | RS_Checked | RS_Verified
  deriving (Show, Eq)

-- | Is received
isReceived :: GoodsReceipt -> Bool
isReceived gr = grStatus gr == RS_Received || grStatus gr == RS_Checked
