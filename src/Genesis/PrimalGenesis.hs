{-# LANGUAGE OverloadedStrings #-}
module Genesis.PrimalGenesis
  ( PrimordialCreation(..)
  , FirstEmergence
  , UltimateOrigin
  , beginGenesis
  ) where

import Data.Text (Text)

-- | Primal genesis type
data PrimordialCreation = PrimordialCreation
  { pcId :: Text
  , pcIsPrimordial :: Bool
  , pcIsUltimate :: Bool
  } deriving (Eq, Show)

-- | First emergence type
type FirstEmergence = PrimordialCreation

-- | Ultimate origin type
type UltimateOrigin = PrimordialCreation

-- | Begin primal genesis
beginGenesis :: PrimordialCreation
beginGenesis = PrimordialCreation "genesis-001" True True