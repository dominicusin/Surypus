-- | AccPlan module - Accounting plan
module Core.AccPlan where

import           Data.Int  (Int64)
import           Data.Text (Text)
import qualified Data.Text as Data.Text

-- | AccPlan - Accounting plan entry
data AccPlan = AccPlan
  { apId         :: Int64
  , apCode       :: Text
  , apName       :: Text
  , apType       :: AccType
  , apParentCode :: Maybe Text
  } deriving (Show, Eq)

data AccType = AT_Asset | AT_Liability | AT_Equity | AT_Revenue | AT_Expense
  deriving (Show, Eq)

-- | Validate account code
validateAccCode :: AccPlan -> Bool
validateAccCode ap = not (Data.Text.null (apCode ap))
