{-# LANGUAGE OverloadedStrings #-}
module Cadence.CosmicRhythm
  ( UniversalCadence(..)
  , StellarTempo
  , GalacticPulse
  , feelRhythm
  ) where

import Data.Text (Text)

-- | Cosmic rhythm type
data UniversalCadence = UniversalCadence
  { ucId :: Text
  , ucIsUniversal :: Bool
  , ucIsGalactic :: Bool
  } deriving (Eq, Show)

-- | Stellar tempo type
type StellarTempo = UniversalCadence

-- | Galactic pulse type
type GalacticPulse = UniversalCadence

-- | Feel cosmic rhythm
feelRhythm :: UniversalCadence
feelRhythm = UniversalCadence "rhythm-001" True True