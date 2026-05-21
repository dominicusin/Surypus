{-# LANGUAGE OverloadedStrings #-}
module Awareness.AbsolutePerception
  ( PerfectAwareness(..)
  , CompleteUnderstanding
  , TotalConsciousness
  , perceiveAbsolute
  ) where

import Data.Text (Text)

-- | Absolute perception type
data PerfectAwareness = PerfectAwareness
  { paId :: Text
  , paIsPerfect :: Bool
  , paIsTotal :: Bool
  } deriving (Eq, Show)

-- | Complete understanding type
type CompleteUnderstanding = PerfectAwareness

-- | Total consciousness type
type TotalConsciousness = PerfectAwareness

-- | Perceive absolute
perceiveAbsolute :: CompleteUnderstanding
perceiveAbsolute = PerfectAwareness "perception-001" True True