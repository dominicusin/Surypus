{-# LANGUAGE OverloadedStrings #-}
module QuantumBeat.QuantumBeat
  ( ProbabilisticRhythm(..)
  , SuperpositionCadence
  , EntangledTempo
  , beatQuantum
  ) where

import Data.Text (Text)

-- | Quantum beat type
data ProbabilisticRhythm = ProbabilisticRhythm
  { prId :: Text
  , prIsProbabilistic :: Bool
  , prIsEntangled :: Bool
  } deriving (Eq, Show)

-- | Superposition cadence type
type SuperpositionCadence = ProbabilisticRhythm

-- | Entangled tempo type
type EntangledTempo = ProbabilisticRhythm

-- | Beat quantum
beatQuantum :: EntangledTempo
beatQuantum = ProbabilisticRhythm "qbeat-001" True True