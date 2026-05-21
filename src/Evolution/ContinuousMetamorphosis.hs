{-# LANGUAGE OverloadedStrings #-}
module Evolution.ContinuousMetamorphosis
  ( EvolutionEngine(..)
  , MetamorphosisState
  , adaptContinuously
  ) where

import Data.Text (Text)
import Data.Aeson (Value)

-- | Evolution engine
data EvolutionEngine = EvolutionEngine
  { eeId :: Text
  , eeGenerations :: Int
  , eeFitness :: Double
  } deriving (Eq, Show)

-- | Metamorphosis state type
type MetamorphosisState = Value

-- | Continuously adapt system
adaptContinuously :: EvolutionEngine -> IO EvolutionEngine
adaptContinuously engine = return $ engine { eeGenerations = eeGenerations engine + 1 }