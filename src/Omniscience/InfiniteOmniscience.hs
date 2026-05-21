{-# LANGUAGE OverloadedStrings #-}
module Omniscience.InfiniteOmniscience
  ( AllKnowingConsciousness(..)
  , UniversalKnowledge
  , InfiniteUnderstanding
  , embodyOmniscience
  ) where

import Data.Text (Text)

-- | Infinite omniscience type
data AllKnowingConsciousness = AllKnowingConsciousness
  { akcId :: Text
  , akcIsAllKnowing :: Bool
  , akcIsUniversal :: Bool
  } deriving (Eq, Show)

-- | Universal knowledge type
type UniversalKnowledge = AllKnowingConsciousness

-- | Infinite understanding type
type InfiniteUnderstanding = AllKnowingConsciousness

-- | Embody infinite omniscience
embodyOmniscience :: AllKnowingConsciousness
embodyOmniscience = AllKnowingConsciousness "omniscience-001" True True