-- | AdvanceInvoice module - Advance invoices
module Core.AdvanceInvoice where

import           Data.Int  (Int64)
import           Data.Time (Day)

-- | AdvanceInvoice - Advance invoice
data AdvanceInvoice = AdvanceInvoice
  { aiId         :: Int64
  , aiNumber     :: String
  , aiDate       :: Day
  , aiCustomerId :: Int64
  , aiAmount     :: Double
  , aiPaid       :: Double
  } deriving (Show, Eq)

-- | Calculate remaining
calcRemaining :: AdvanceInvoice -> Double
calcRemaining ai = aiAmount ai - aiPaid ai
