-- | Payment module - Payments (corresponds to PaymentTbl in C++)
module Core.Payment where

import Data.Int (Int64)
import Data.Text (Text)
import Data.Time (Day)
import Test.QuickCheck

-- ============================================================================
-- PAYMENT TYPES
-- ============================================================================

-- | Payment - Payment record
data Payment = Payment
  { payId :: Int64,
    payBillId :: Int64, -- Linked bill ID
    payDate :: Day,
    payAmount :: Double,
    payMethod :: PaymentMethod,
    payStatus :: PaymentStatus,
    payCardId :: Maybe Int64, -- Card ID for card payments
    payCashRegId :: Maybe Int64, -- Cash register ID
    payFlags :: Int
  }
  deriving (Show, Eq)

-- | Payment method - corresponds to PPPAYMT_*
data PaymentMethod
  = PM_Cash -- Cash (Наличные)
  | PM_Card -- Card (Карта)
  | PM_Transfer -- Bank transfer (Безналичные)
  | PM_Bonus -- Bonus points (Бонусы)
  | PM_GiftCard -- Gift card (Подарочная карта)
  | PM_Credit -- Credit (Кредит)
  deriving (Show, Eq, Enum)

-- | Payment status
data PaymentStatus
  = PS_Pending -- Pending (Ожидание)
  | PS_Completed -- Completed (Проведен)
  | PS_Failed -- Failed (Ошибка)
  | PS_Refunded -- Refunded (Возвращен)
  | PS_Cancelled -- Cancelled (Отменен)
  deriving (Show, Eq)

-- | Payment flags - corresponds to PAYMF_*
data PaymentFlags = PaymentFlags
  { pfRetrieved :: Bool, -- PAYMF_RETRIEVED
    pfOnline :: Bool, -- PAYMF_ONLINE
    pfPreauth :: Bool -- PAYMF_PREAUTH (pre-authorization)
  }
  deriving (Show, Eq)

-- ============================================================================
-- PAYMENT FUNCTIONS
-- ============================================================================

-- | Check if payment is completed
isCompleted :: Payment -> Bool
isCompleted p = payStatus p == PS_Completed

-- | Check if payment can be refunded
canRefund :: Payment -> Bool
canRefund p = payStatus p == PS_Completed && payAmount p > 0

-- | Calculate payment amount (ensure non-negative)
calcPaymentAmount :: Double -> Double
calcPaymentAmount = max 0

-- | Validate payment
validatePayment :: Payment -> Bool
validatePayment p = payAmount p > 0

-- ============================================================================
-- QUICKCHECK PROPERTIES
-- ============================================================================

-- | Property: Payment amount is non-negative
prop_payment_amount_positive :: Payment -> Property
prop_payment_amount_positive p =
  property (payAmount p >= 0)
