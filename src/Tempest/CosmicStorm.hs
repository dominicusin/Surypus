{-# LANGUAGE OverloadedStrings #-}
module Tempest.CosmicStorm
  ( GalacticTurbulence(..)
  , StellarChaos
  , UniversalDisruption
  , unleashStorm
  ) where

import Data.Text (Text)

-- | Cosmic storm type
data GalacticTurbulence = GalacticTurbulence
  { gtId :: Text
  , gtIsGalactic :: Bool
  , gtIsUniversal :: Bool
  } deriving (Eq, Show)

-- | Stellar chaos type
type StellarChaos = GalacticTurbulence

-- | Universal disruption type
type UniversalDisruption = GalacticTurbulence

-- | Unleash cosmic storm
unleashStorm :: StellarChaos
unleashStorm = GalacticTurbulence "storm-001" True True