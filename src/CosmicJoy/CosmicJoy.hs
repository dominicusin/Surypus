{-# LANGUAGE OverloadedStrings #-}
module CosmicJoy.CosmicJoy
  ( GalacticDelight(..)
  , StellarEuphoria
  , UniversalRapture
  , experienceCosmicJoy
  ) where

import Data.Text (Text)

-- | Cosmic joy type
data GalacticDelight = GalacticDelight
  { gdId :: Text
  , gdIsGalactic :: Bool
  , gdIsUniversal :: Bool
  } deriving (Eq, Show)

-- | Stellar euphoria type
type StellarEuphoria = GalacticDelight

-- | Universal rapture type
type UniversalRapture = GalacticDelight

-- | Experience cosmic joy
experienceCosmicJoy :: GalacticDelight
experienceCosmicJoy = GalacticDelight "cosmicjoy-001" True True