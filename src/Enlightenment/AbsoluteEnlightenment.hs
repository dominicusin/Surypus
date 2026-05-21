{-# LANGUAGE OverloadedStrings #-}
module Enlightenment.AbsoluteEnlightenment
  ( PerfectAwakening(..)
  , CompleteRealization
  , TotalIllumination
  , achieveEnlightenment
  ) where

import Data.Text (Text)

-- | Absolute enlightenment type
data PerfectAwakening = PerfectAwakening
  { paId :: Text
  , paIsPerfect :: Bool
  , paIsTotal :: Bool
  } deriving (Eq, Show)

-- | Complete realization type
type CompleteRealization = PerfectAwakening

-- | Total illumination type
type TotalIllumination = PerfectAwakening

-- | Achieve absolute enlightenment
achieveEnlightenment :: CompleteRealization
achieveEnlightenment = PerfectAwakening "enlightenment-001" True True