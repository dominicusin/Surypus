{-# LANGUAGE OverloadedStrings #-}
module QuantumEnlightenment.QuantumEnlightenment
  ( SubatomicAwakening(..)
  , ParticleConsciousness
  , DualityIllumination
  , achieveQuantumEnlightenment
  ) where

import Data.Text (Text)

-- | Quantum enlightenment type
data SubatomicAwakening = SubatomicAwakening
  { saId :: Text
  , saIsSubatomic :: Bool
  , saIsIlluminated :: Bool
  } deriving (Eq, Show)

-- | Particle consciousness type
type ParticleConsciousness = SubatomicAwakening

-- | Wave-particle duality illumination type
type DualityIllumination = SubatomicAwakening

-- | Achieve quantum enlightenment
achieveQuantumEnlightenment :: SubatomicAwakening
achieveQuantumEnlightenment = SubatomicAwakening "quantumenlightenment-001" True True