-- | InventoryEx module - Extended inventory
module Core.InventoryEx where

import           Data.Int  (Int64)
import           Data.Text (Text)
import           Data.Time (Day)

-- | InventoryEx - Extended inventory
data InventoryEx = InventoryEx
  { invId         :: Int64
  , invCode       :: Text
  , invDate       :: Day
  , invLocationId :: Int64
  , invStatus     :: InvStatus
  } deriving (Show, Eq)

data InvStatus = IS_Draft | IS_InProgress | IS_Completed | IS_Cancelled
  deriving (Show, Eq)

-- | Is inventory active
isActive :: InventoryEx -> Bool
isActive i = invStatus i == IS_InProgress
