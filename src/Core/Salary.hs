-- | Salary module - Salary calculation
module Core.Salary where

import           Data.Int  (Int64)
import           Data.Text (Text)
import           Data.Time (Day)

-- | Salary - Salary calculation
data Salary = Salary
  { salId         :: Int64
  , salEmployeeId :: Int64
  , salPeriod     :: Day
  , salBase       :: Double
  , salBonus      :: Double
  , salTax        :: Double
  , salNet        :: Double
  } deriving (Show, Eq)

-- | SalaryItem - Salary component
data SalaryItem = SalaryItem
  { siId       :: Int64
  , siSalaryId :: Int64
  , siType     :: SalaryItemType
  , siAmount   :: Double
  } deriving (Show, Eq)

data SalaryItemType = SIT_Base | SIT_Bonus | SIT_Penalty | SIT_Tax | SIT_Advance
  deriving (Show, Eq)
