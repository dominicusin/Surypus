{-# LANGUAGE OverloadedStrings #-}
module CosmicWholeness.CosmicWholeness
  ( GalacticPerfection(..)
  , StellarCompletion
  , UniversalHarmony
  , resonateWholeness
  ) where

import Data.Text (Text)

-- | Cosmic wholeness type
data GalacticPerfection = GalacticPerfection
  { gpId :: Text
  , gpIsGalactic :: Bool
  , gpIsUniversal :: Bool
  } deriving (Eq, Show)

-- | Stellar completion type
type StellarCompletion = GalacticPerfection

-- | Universal harmony type
type UniversalHarmony = GalacticPerfection

-- | Resonate wholeness
resonateWholeness :: GalacticPerfection
resonateWholeness = GalacticPerfection "cosmicwholeness-001" True True