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

data DiscountType = DTPercent | DTFixed | DTConditional
  deriving (Show, Eq)

-- | Calculate discount amount
calcDiscount :: Discount -> Double -> Double
calcDiscount d amount
  | amount >= dscMinAmount d = case dscType d of
      DTPercent     -> amount * dscValue d / 100
      DTFixed       -> dscValue d
      DTConditional -> amount * dscValue d / 100
  | otherwise = 0
