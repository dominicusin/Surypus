-- | AccMask module - Accounting mask
module Core.AccMask where

import Data.Int (Int64)
import Data.Text (Text)

-- | AccMask - Accounting mask (template)
data AccMask = AccMask
  { amId :: Int64,
    amName :: Text,
    amObjectType :: Int64,
    amDebitAccId :: Int64,
    amCreditAccId :: Int64,
    amFlags :: Int
  }
  deriving (Show, Eq)

-- | AccRel - Accounting relation
data AccRel = AccRel
  { arId :: Int64,
    arBillId :: Int64,
    arOpKindId :: Int64,
    arAccMaskId :: Int64,
    arFlags :: Int
  }
  deriving (Show, Eq)
