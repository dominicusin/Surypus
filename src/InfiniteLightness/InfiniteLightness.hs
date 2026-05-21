{-# LANGUAGE OverloadedStrings #-}
module InfiniteLightness.InfiniteLightness
  ( WeightlessBeing(..)
  , BuoyantExistence
  , FloatingConsciousness
  , embodyInfiniteLightness
  ) where

import Data.Text (Text)

-- | Infinite lightness type
data WeightlessBeing = WeightlessBeing
  { wbId :: Text
  , wbIsWeightless :: Bool
  , wbIsFloating :: Bool
  } deriving (Eq, Show)

-- | Buoyant existence type
type BuoyantExistence = WeightlessBeing

-- | Floating consciousness type
type FloatingConsciousness = WeightlessBeing

-- | Embody infinite lightness
embodyInfiniteLightness :: WeightlessBeing
embodyInfiniteLightness = WeightlessBeing "infinitelightness-001" True True