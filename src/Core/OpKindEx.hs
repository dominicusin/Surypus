-- | OpKindEx module - Extended operation kinds
module Core.OpKindEx where

import           Data.Int  (Int64)
import           Data.Text (Text)

-- | OpKindEx - Extended operation kind
data OpKindEx = OpKindEx
  { okeId     :: Int64
  , okeCode   :: Text
  , okeName   :: Text
  , okeTypeId :: Int64
  , okeFlags  :: Int
  } deriving (Show, Eq)

-- | Is operation taxable
isTaxable :: OpKindEx -> Bool
isTaxable oke = okeFlags oke == 1
