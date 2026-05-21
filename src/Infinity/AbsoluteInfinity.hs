{-# LANGUAGE OverloadedStrings #-}
module Infinity.AbsoluteInfinity
  ( BeyondAll(..)
  , AbsoluteLimitlessness
  , CompleteInfinity
  , realizeInfinity
  ) where

import Data.Text (Text)

-- | Absolute infinity type
data BeyondAll = BeyondAll
  { baId :: Text
  , baIsBeyond :: Bool
  , baIsAbsolute :: Bool
  } deriving (Eq, Show)

-- | Absolute limitlessness type
type AbsoluteLimitlessness = BeyondAll

-- | Complete infinity type
type CompleteInfinity = BeyondAll

-- | Realize absolute infinity
realizeInfinity :: AbsoluteLimitlessness
realizeInfinity = BeyondAll "infinity-001" True True