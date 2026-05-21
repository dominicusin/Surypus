{-# LANGUAGE OverloadedStrings #-}
module Omniscient.OmniscientSystems
  ( OmniscientState(..)
  , AllKnowing
  , UniversalAwareness
  , knowAll
  ) where

import Data.Text (Text)
import Data.Aeson (Value)

-- | Omniscient state type
data OmniscientState = OmniscientState
  { osId :: Text
  , osComplete :: Bool
  , osAwarenessLevel :: Double
  } deriving (Eq, Show)

-- | All-knowing type
type AllKnowing = OmniscientState

-- | Universal awareness type
type UniversalAwareness = Value -> IO Value

-- | Know all states
knowAll :: UniversalAwareness
knowAll input = return input