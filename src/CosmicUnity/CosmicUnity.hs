{-# LANGUAGE OverloadedStrings #-}
module CosmicUnity.CosmicUnity
  ( GalacticOneness(..)
  , StellarHarmony
  , UniversalSynthesis
  , attainCosmicUnity
  ) where

import Data.Text (Text)

-- | Cosmic unity type
data GalacticOneness = GalacticOneness
  { goId :: Text
  , goIsGalactic :: Bool
  , goIsUniversal :: Bool
  } deriving (Eq, Show)

-- | Stellar harmony type
type StellarHarmony = GalacticOneness

-- | Universal synthesis type
type UniversalSynthesis = GalacticOneness

-- | Attain cosmic unity
attainCosmicUnity :: GalacticOneness
attainCosmicUnity = GalacticOneness "cosmicunity-001" True True