-- | Preorder module - Preorders
module Core.Preorder where

import           Data.Int  (Int64)
import           Data.Text (Text)
import           Data.Time (Day)

-- | Preorder - Preorder
data Preorder = Preorder
  { poId           :: Int64
  , poCode         :: Text
  , poDate         :: Day
  , poCustomerId   :: Int64
  , poExpectedDate:: Day
  , poStatus       :: PreorderStatus
  } deriving (Show, Eq)

data PreorderStatus = POS_Pending | POS_Confirmed | POS_Shipped | POS_Completed | POS_Cancelled
  deriving (Show, Eq)

-- | Is preorder active
isPreorderActive :: Preorder -> Bool
isPreorderActive p = poStatus p == POS_Pending || poStatus p == POS_Confirmed
