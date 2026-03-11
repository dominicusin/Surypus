-- | BillStatusEx module - Extended bill status
module Core.BillStatusEx where

import           Data.Int  (Int64)
import           Data.Text (Text)

-- | BillStatusEx - Extended bill status
data BillStatusEx = BillStatusEx
  { bseId        :: Int64
  , bseBillId    :: Int64
  , bseStatus    :: BillStatEx
  , bseChangedAt :: Int64
  , bseChangedBy :: Int64
  } deriving (Show, Eq)

data BillStatEx = BSE_Draft | BSE_Registered | BSE_Posted | BSE_Annuled
  deriving (Show, Eq)

-- | Is bill posted
isPosted :: BillStatusEx -> Bool
isPosted b = bseStatus b == BSE_Posted
