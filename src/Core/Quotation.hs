-- | Quotation module - Commercial offers
module Core.Quotation where

import           Data.Int  (Int64)
import           Data.Text (Text)
import           Data.Time (Day)

-- | Quotation - Commercial offer
data Quotation = Quotation
  { qotId        :: Int64
  , qotCode      :: Text
  , qotClientId  :: Int64
  , qotDate      :: Day
  , qotValidTill :: Maybe Day
  , qotStatus    :: QuotationStatus
  , qotFlags     :: Int
  } deriving (Show, Eq)

data QuotationStatus = QSDraft | QSSent | QSAccepted | QSRejected | QSExpired
  deriving (Show, Eq)

-- | Quotation line
data QuotationLine = QuotationLine
  { qlId          :: Int64
  , qlQuotationId :: Int64
  , qlGoodsId     :: Int64
  , qlQtty        :: Double
  , qlPrice       :: Double
  , qlDiscount    :: Double
  } deriving (Show, Eq)

-- | Calculate total
calcQuotationTotal :: QuotationLine -> Double
calcQuotationTotal ql = qlQtty ql * qlPrice ql * (1 - qlDiscount ql / 100)
