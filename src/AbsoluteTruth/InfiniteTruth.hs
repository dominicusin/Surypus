{-# LANGUAGE OverloadedStrings #-}
module AbsoluteTruth.InfiniteTruth
  ( UniversalVerity(..)
  , PerpetualReality
  , AbsoluteFact
  , embodyInfiniteTruth
  ) where

import Data.Text (Text)

-- | Infinite truth type
data UniversalVerity = UniversalVerity
  { uvId :: Text
  , uvIsUniversal :: Bool
  , uvIsAbsolute :: Bool
  } deriving (Eq, Show)

-- | Perpetual reality type
type PerpetualReality = UniversalVerity

-- | Absolute fact type
type AbsoluteFact = UniversalVerity

-- | Embody infinite truth
embodyInfiniteTruth :: UniversalVerity
embodyInfiniteTruth = UniversalVerity "truth-001" True True