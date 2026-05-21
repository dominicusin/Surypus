{-# LANGUAGE OverloadedStrings #-}
module End.CosmicEndState
  ( EndState(..)
  , Singularity
  , UniversalConvergence
  , reachEnd
  ) where

import Data.Text (Text)

-- | End state type
data EndState = EndState
  { esId :: Text
  , esIsComplete :: Bool
  , esIsEternal :: Bool
  } deriving (Eq, Show)

-- | Singularity type
type Singularity = EndState

-- | Universal convergence type
type UniversalConvergence = ()

-- | Reach the end state
reachEnd :: Singularity
reachEnd = EndState "end-001" True True