{-# LANGUAGE OverloadedStrings #-}
module Potential.AbsolutePotential
  ( UnlimitedPossibility(..)
  , AbsoluteCapacity
  , InfiniteProbability
  , unlockPotential
  ) where

import Data.Text (Text)

-- | Absolute potential type
data UnlimitedPossibility = UnlimitedPossibility
  { upId :: Text
  , upIsUnlimited :: Bool
  , upIsInfinite :: Bool
  } deriving (Eq, Show)

-- | Absolute capacity type
type AbsoluteCapacity = UnlimitedPossibility

-- | Infinite probability type
type InfiniteProbability = UnlimitedPossibility

-- | Unlock absolute potential
unlockPotential :: AbsoluteCapacity
unlockPotential = UnlimitedPossibility "potential-001" True True