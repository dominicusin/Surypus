-- | DebitNote module - Debit notes
module Core.DebitNote where

import Data.Int (Int64)
import Data.Text (Text)
import Data.Time (Day)

-- | DebitNote - Debit note
data DebitNote = DebitNote
  { dnId :: Int64,
    dnCode :: Text,
    dnDate :: Day,
    dnBillId :: Int64,
    dnAmount :: Double,
    dnReason :: Text
  }
  deriving (Show, Eq)

-- | Validate debit note
isValidDebitNote :: DebitNote -> Bool
isValidDebitNote dn = dnAmount dn > 0
