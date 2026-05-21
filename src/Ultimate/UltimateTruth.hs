{-# LANGUAGE OverloadedStrings #-}
module Ultimate.UltimateTruth
  ( UltimateTruth(..)
  , UnifiedTheory
  , CosmicEnlightenment
  , revealTruth
  ) where

import Data.Text (Text)
import Data.Aeson (Value)

-- | Ultimate truth type
data UltimateTruth = UltimateTruth
  { utId :: Text
  , utIsAbsolute :: Bool
  , utIsComplete :: Bool
  } deriving (Eq, Show)

-- | Unified theory type
type UnifiedTheory = Value -> Value

-- | Cosmic enlightenment type
type CosmicEnlightenment = UltimateTruth

-- | Reveal ultimate truth
revealTruth :: UnifiedTheory
revealTruth input = input