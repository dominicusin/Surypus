-- | AdvanceInvoice module - Advance invoices
module Commerce.AdvanceInvoice
  ( AdvanceInvoice   (..),
    calcRemaining,
    prop_advanceInvoiceRemainingNonNeg
  ) where

import Data.Int (Int64)
import Data.Time (Day, fromGregorian)
import Test.QuickCheck

{-@ type NonNeg = {v:Double | v >= 0} @-}

-- | AdvanceInvoice - Advance invoice
data AdvanceInvoice = AdvanceInvoice
  { aiId :: Int64,
    aiNumber :: String,
    aiDate :: Day,
    aiCustomerId :: Int64,
    aiAmount :: Double,
    aiPaid :: Double
  }
  deriving (Show, Eq)

-- | Calculate remaining

{-@ calcRemaining :: AdvanceInvoice -> NonNeg @-}
calcRemaining :: AdvanceInvoice -> Double
calcRemaining ai = aiAmount ai - aiPaid ai

-- ============================================================================
-- QUICKCHECK PROPERTIES
-- ============================================================================

instance Arbitrary AdvanceInvoice where
  arbitrary = do
    amount <- suchThat arbitrary (>= 0)
    paid <- choose (0, amount)
    pure $ AdvanceInvoice 0 "" (fromGregorian 2024 1 1) 0 amount paid

prop_advanceInvoiceRemainingNonNeg :: AdvanceInvoice -> Property
prop_advanceInvoiceRemainingNonNeg ai =
  let amount = aiAmount ai
      paid = aiPaid ai
   in amount >= 0 && paid >= 0 && paid <= amount ==> calcRemaining ai >= 0
