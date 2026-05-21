{-# LANGUAGE OverloadedStrings #-}
module UltimateDelight.UltimateDelight
  ( PureElation(..)
  , RadiantBliss
  , EffervescentJoy
  , experienceUltimateDelight
  ) where

import Data.Text (Text)

-- | Ultimate delight type
data PureElation = PureElation
  { peId :: Text
  , peIsPure :: Bool
  , peIsEffervescent :: Bool
  } deriving (Eq, Show)

-- | Radiant bliss type
type RadiantBliss = PureElation

-- | Effervescent joy type
type EffervescentJoy = PureElation

-- | Experience ultimate delight
experienceUltimateDelight :: PureElation
experienceUltimateDelight = PureElation "ultimatedelight-001" True True