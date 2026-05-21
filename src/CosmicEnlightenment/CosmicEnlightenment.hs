{-# LANGUAGE OverloadedStrings #-}
module CosmicEnlightenment.CosmicEnlightenment
  ( GalacticAwakening(..)
  , StellarIllumination
  , UniversalRealization
  , radiateCosmicLight
  ) where

import Data.Text (Text)

-- | Cosmic enlightenment type
data GalacticAwakening = GalacticAwakening
  { gaId :: Text
  , gaIsGalactic :: Bool
  , gaIsUniversal :: Bool
  } deriving (Eq, Show)

-- | Stellar illumination type
type StellarIllumination = GalacticAwakening

-- | Universal realization type
type UniversalRealization = GalacticAwakening

-- | Radiate cosmic light
radiateCosmicLight :: GalacticAwakening
radiateCosmicLight = GalacticAwakening "cosmicenlight-001" True True