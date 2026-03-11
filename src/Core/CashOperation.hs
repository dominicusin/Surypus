-- | CashOperation module - Cash operations
module Core.CashOperation where

import           Data.Int  (Int64)
import           Data.Text (Text)
import           Data.Time (Day)

-- | CashOperation - Cash operation
data CashOperation = CashOperation
  { coId         :: Int64
  , coDate       :: Day
  , coType       :: CashOpType
  , coAmount     :: Double
  , coRegisterId :: Int64
  , coReason     :: Text
  } deriving (Show, Eq)

data CashOpType = CO_Income | CO_Expense | CO_Transfer | CO_Exchange
  deriving (Show, Eq)

-- | Is income operation
isIncome :: CashOperation -> Bool
isIncome co = coType co == CO_Income
