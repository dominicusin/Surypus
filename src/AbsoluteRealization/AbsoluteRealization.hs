{-# LANGUAGE OverloadedStrings #-}
module AbsoluteRealization.AbsoluteRealization
  ( TotalAwakening(..)
  , CompleteUnderstanding
  , AbsoluteTruth
  , realizeAbsolute
  ) where

import Data.Text (Text)

-- | Absolute realization type
data TotalAwakening = TotalAwakening
  { taId :: Text
  , taIsTotal :: Bool
  , taIsAbsolute :: Bool
  } deriving (Eq, Show)

-- | Complete understanding type
type CompleteUnderstanding = TotalAwakening

-- | Absolute truth type
type AbsoluteTruth = TotalAwakening

-- | Realize absolute
realizeAbsolute :: CompleteUnderstanding
realizeAbsolute = TotalAwakening "absolutereal-001" True True