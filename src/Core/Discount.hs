-- | Discount module - Discounts
module Core.Discount where

import           Data.Int  (Int64)
import           Data.Text (Text)

-- | Discount - Discount rule
data Discount = Discount
  { dscId        :: Int64
  , dscCode      :: Text
  , dscName      :: Text
  , dscType      :: DiscountType
  , dscValue     :: Double
  , dscMinAmount :: Double
  } deriving (Show, Eq)

data DiscountType = DT_Percent | DT_Fixed | DT_Conditional
  deriving (Show, Eq)

-- | Calculate discount amount
calcDiscount :: Discount -> Double -> Double
calcDiscount d amount
  | amount >= dscMinAmount d = case dscType d of
      DT_Percent     -> amount * dscValue d / 100
      DT_Fixed       -> dscValue d
      DT_Conditional -> amount * dscValue d / 100
  | otherwise = 0
