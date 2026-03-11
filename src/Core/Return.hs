-- | Return module - Returns
module Core.Return where

import           Data.Int  (Int64)
import           Data.Text (Text)
import           Data.Time (Day)

-- | Return - Return record
data Return = Return
  { retId      :: Int64
  , retCode    :: Text
  , retDate    :: Day
  , retOrderId :: Int64
  , retReason  :: Text
  , retStatus  :: ReturnStatus
  } deriving (Show, Eq)

data ReturnStatus = RS_Pending | RS_Approved | RS_Rejected | RS_Completed
  deriving (Show, Eq)

-- | Is return completed
isReturnCompleted :: Return -> Bool
isReturnCompleted r = retStatus r == RS_Completed
