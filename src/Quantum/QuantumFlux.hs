{-# LANGUAGE OverloadedStrings #-}
module Quantum.QuantumFlux
  ( QuantumUncertainty(..)
  , ProbabilisticStates
  , SuperpositionDynamics
  , observeQuantum
  ) where

import Data.Text (Text)

-- | Quantum flux type
data QuantumUncertainty = QuantumUncertainty
  { quId :: Text
  , quIsUncertain :: Bool
  , quIsSuperposed :: Bool
  } deriving (Eq, Show)

-- | Probabilistic states type
type ProbabilisticStates = QuantumUncertainty

-- | Superposition dynamics type
type SuperpositionDynamics = QuantumUncertainty

-- | Observe quantum state
observeQuantum :: QuantumUncertainty
observeQuantum = QuantumUncertainty "quantum-001" True True