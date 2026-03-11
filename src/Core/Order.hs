-- | Order module - Sales orders
module Core.Order where

import           Data.Int  (Int64)
import           Data.Text (Text)
import           Data.Time (Day)

-- | Order - Sales order
data Order = Order
  { ordId           :: Int64
  , ordCode         :: Text
  , ordClientId     :: Int64
  , ordDate         :: Day
  , ordDeliveryDate:: Maybe Day
  , ordStatus       :: OrderStatus
  , ordFlags        :: Int
  } deriving (Show, Eq)

data OrderStatus = OS_Draft | OS_Confirmed | OS_InProgress | OS_Completed | OS_Cancelled
  deriving (Show, Eq)

-- | Order line
data OrderLine = OrderLine
  { olId       :: Int64
  , olOrderId  :: Int64
  , olGoodsId  :: Int64
  , olQtty     :: Double
  , olPrice    :: Double
  , olDiscount :: Double
  , olStatus   :: LineStatus
  } deriving (Show, Eq)

data LineStatus = LS_Pending | LS_Reserved | LS_Shipped | LS_Returned
  deriving (Show, Eq)

-- | Calculate order total
calcOrderTotal :: [OrderLine] -> Double
calcOrderTotal lines = sum (map calcLineTotal lines)

calcLineTotal :: OrderLine -> Double
calcLineTotal ol = olQtty ol * olPrice ol * (1 - olDiscount ol / 100)
