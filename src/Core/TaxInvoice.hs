-- | TaxInvoice module - Tax invoices
module Core.TaxInvoice where

import           Data.Int  (Int64)
import           Data.Time (Day)

-- | TaxInvoice - Tax invoice
data TaxInvoice = TaxInvoice
  { tiId        :: Int64
  , tiNumber    :: String
  , tiDate      :: Day
  , tiBillId    :: Int64
  , tiTotal     :: Double
  , tiTaxAmount :: Double
  } deriving (Show, Eq)

-- | Calculate tax amount
calcTaxAmount :: Double -> Double -> Double
calcTaxAmount amount rate = amount * rate / 100
