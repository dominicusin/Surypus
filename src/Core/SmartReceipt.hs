-- | SmartReceipt module - Electronic receipts
module Core.SmartReceipt where

import           Data.Int  (Int64)
import           Data.Text (Text)
import           Data.Time (Day, UTCTime)

-- | SmartReceipt - Electronic receipt
data SmartReceipt = SmartReceipt
  { srId          :: Int64
  , srCode        :: Text
  , srSessionId   :: Int64
  , srDate        :: Day
  , srTime        :: UTCTime
  , srTotal       :: Double
  , srTax         :: Double
  , srPaymentType :: PaymentType
  , srStatus      :: ReceiptStatus
  } deriving (Show, Eq)

data PaymentType = PT_Cash | PT_Card | PT_Online | PT_Bonus
  deriving (Show, Eq)

data ReceiptStatus = RS_Printed | RS_Sent | RS_Returned
  deriving (Show, Eq)

-- | SmartReceiptLine - Receipt line
data SmartReceiptLine = SmartReceiptLine
  { srlId        :: Int64
  , srlReceiptId :: Int64
  , srlGoodsId   :: Int64
  , srlName      :: Text
  , srlQtty      :: Double
  , srlPrice     :: Double
  , srlDiscount  :: Double
  , srlTax       :: Double
  } deriving (Show, Eq)

-- | Calculate receipt total
calcReceiptTotal :: [SmartReceiptLine] -> Double
calcReceiptTotal lines = sum (map lineTotal lines)
  where lineTotal l = srlQtty l * srlPrice l * (1 - srlDiscount l / 100)
