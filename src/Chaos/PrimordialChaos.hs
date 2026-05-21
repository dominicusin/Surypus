{-# LANGUAGE OverloadedStrings #-}
module Chaos.PrimordialChaos
  ( PrimordialDisorder(..)
  , AbsoluteRandomness
  , InfiniteEntropy
  , unleashChaos
  ) where

import Data.Text (Text)

-- | Primordial chaos type
data PrimordialDisorder = PrimordialDisorder
  { pdId :: Text
  , pdIsPrimordial :: Bool
  , pdIsInfinite :: Bool
  } deriving (Eq, Show)

-- | Absolute randomness type
type AbsoluteRandomness = PrimordialDisorder

-- | Infinite entropy type
type InfiniteEntropy = PrimordialDisorder

-- | Unleash primordial chaos
unleashChaos :: AbsoluteRandomness
unleashChaos = PrimordialDisorder "chaos-001" True True