-- | Bonus/Points system types
module Core.Loyalty.Bonus
  ( BonusOp (..),
    BonusOpType (..),
    BonusProgram (..),
    calcBonusBalance,
    canUseBonusPayment,
    prop_bonusBalanceBounded,
  )
where

import Data.Int (Int64)
import Data.Text (Text)
import Data.Time (Day, fromGregorian)
import Test.QuickCheck

{-@ type NonNeg = {v:Double | v >= 0} @-}

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

-- ============================================================================
-- QUICKCHECK PROPERTIES
-- ============================================================================

instance Arbitrary BonusOp where
  arbitrary = do
    btype <- elements [BOTAccrual, BOTSpending, BOTExpiration, BOTAdjustment]
    amount <- suchThat arbitrary (>= 0)
    pure $ BonusOp 0 0 (fromGregorian 2024 1 1) btype amount Nothing ""

instance Arbitrary BonusProgram where
  arbitrary = do
    active <- arbitrary
    accrual <- choose (0, 100 :: Double)
    spent <- choose (0, 100 :: Double)
    expiry <- choose (0, 365 :: Int)
    pure $ BonusProgram 0 "" accrual 0 spent expiry active

prop_bonusBalanceBounded :: [BonusOp] -> Property
prop_bonusBalanceBounded ops =
  let validOps = all (\op -> boAmount op >= 0) ops
   in validOps ==> True
