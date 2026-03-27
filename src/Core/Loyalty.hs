-- | Loyalty Module - Discount cards and bonus programs
-- Re-exports all loyalty-related types
module Core.Loyalty
  ( module Core.Loyalty.Card,
    module Core.Loyalty.Bonus,
  )
where

import Core.Loyalty.Bonus
import Core.Loyalty.Card
