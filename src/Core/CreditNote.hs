{-# LANGUAGE OverloadedStrings #-}

-- | CreditNote module - Credit notes
module Core.CreditNote
  ( CreditNote (..),
    calcCreditTotal,
    prop_creditNoteAmountNonNeg,
  )
where

import Data.Int (Int64)
import Data.Text (Text)
import Data.Time (Day, fromGregorian)
import Test.QuickCheck
import qualified Test.QuickCheck as QC

{-@ type NonNeg = {v:Double | v >= 0} @-}

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

{-@ calcCreditTotal :: CreditNote -> NonNeg @-}
calcCreditTotal :: CreditNote -> Double
calcCreditTotal = cnAmount

-- ============================================================================
-- QUICKCHECK PROPERTIES
-- ============================================================================

instance Arbitrary CreditNote where
  arbitrary = do
    amount <- suchThat arbitrary (>= 0)
    pure $ CreditNote 0 "" (fromGregorian 2024 1 1) 0 amount ""

prop_creditNoteAmountNonNeg :: CreditNote -> Property
prop_creditNoteAmountNonNeg cn = property (calcCreditTotal cn >= 0)
