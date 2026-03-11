-- | Loyalty Module - Discount cards and bonus programs
-- Re-exports all loyalty-related types
module Core.Loyalty
  ( module Core.Loyalty.Card,
    module Core.Loyalty.Bonus,
  )
where

import Core.Loyalty.Bonus
import Core.Loyalty.Card
import Data.Time (Day)

-- | Calculate discount from card
calcCardDiscount :: DiscountCard -> Double -> Double
calcCardDiscount card amount =
  if amount >= 0
    then amount * dcPercent card / 100
    else 0

-- | Check if card is expired
isCardExpired :: DiscountCard -> Day -> Bool
isCardExpired card today =
  case dcExpires card of
    Nothing -> False
    Just expiry -> today > expiry

-- | Check if card is valid
isCardValid :: DiscountCard -> Day -> Bool
isCardValid card today = not (isCardExpired card today)
