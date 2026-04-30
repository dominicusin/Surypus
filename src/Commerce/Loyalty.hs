-- | Loyalty Module - Discount cards and bonus programs
-- Re-exports all loyalty-related types
module Commerce.Loyalty  where
  ( module Commerce.Loyalty.Card,
    module Commerce.Loyalty.Bonus,
  )
where

import Commerce.Loyalty.Bonus
import Commerce.Loyalty.Card
