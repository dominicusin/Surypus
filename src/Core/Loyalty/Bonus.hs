-- | Bonus/Points system types
module Core.Loyalty.Bonus where

import Data.Int (Int64)
import Data.Text (Text)
import Data.Time (Day)

-- | Bonus operation (начисление/списание бонусов)
data BonusOp = BonusOp
  { boId :: Int64,
    boCardId :: Int64,
    boDate :: Day,
    boType :: BonusOpType,
    boAmount :: Double, -- Amount in bonuses
    boBillId :: Maybe Int64, -- Related bill
    boDescription :: Text
  }
  deriving (Show, Eq)

-- | Bonus operation type
data BonusOpType
  = BOTAccrual -- Accrual (начисление)
  | BOTSpending -- Spending (списание)
  | BOTExpiration -- Expiration (сгорание)
  | BOTAdjustment -- Adjustment (корректировка)
  deriving (Show, Eq, Enum)

-- | Bonus program (бонусная программа)
data BonusProgram = BonusProgram
  { bpId :: Int64,
    bpName :: Text,
    bpAccrualPercent :: Double, -- Percent for accrual
    bpMinSumForAccrual :: Double, -- Min sum for accrual
    bpSpentPercent :: Double, -- Percent for spending
    bpExpiryDays :: Int, -- Days until expiration
    bpActive :: Bool
  }
  deriving (Show, Eq)

-- | Check bonus balance
calcBonusBalance :: [BonusOp] -> Double
calcBonusBalance ops =
  let accruals = sum [boAmount op | op <- ops, boType op == BOTAccrual]
      spendings = sum [boAmount op | op <- ops, boType op == BOTSpending]
   in accruals - spendings

-- | Check if card can be used for payment
canUseBonusPayment :: BonusProgram -> Double -> Bool
canUseBonusPayment bp balance = bpActive bp && balance > 0
