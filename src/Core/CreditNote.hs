-- | CreditNote module - Credit notes
module Core.CreditNote where

import Data.Int (Int64)
import Data.Text (Text)
import Data.Time (Day)

-- | CreditNote - Credit note
data CreditNote = CreditNote
  { cnId :: Int64,
    cnCode :: Text,
    cnDate :: Day,
    cnBillId :: Int64,
    cnAmount :: Double,
    cnReason :: Text
  }
  deriving (Show, Eq)

-- | Calculate credit note total
calcCreditTotal :: CreditNote -> Double
calcCreditTotal = cnAmount
