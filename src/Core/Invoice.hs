-- | Invoice module - Invoices
module Core.Invoice where

import           Data.Int  (Int64)
import           Data.Text (Text)
import           Data.Time (Day)

-- | Invoice - Invoice
data Invoice = Invoice
  { invId      :: Int64
  , invCode    :: Text
  , invDate    :: Day
  , invDueDate :: Day
  , invBillId  :: Int64
  , invTotal   :: Double
  , invPaid    :: Double
  } deriving (Show, Eq)

-- | Calculate invoice balance
calcInvoiceBalance :: Invoice -> Double
calcInvoiceBalance i = invTotal i - invPaid i
