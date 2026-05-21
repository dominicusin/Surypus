{-# LANGUAGE OverloadedStrings #-}
module AbsoluteResolution.AbsoluteResolution
  ( PerfectFinality(..)
  , CompleteConclusion
  , TotalSynthesis
  , resolveAbsolutely
  ) where

import Data.Text (Text)

-- | Absolute resolution type
data PerfectFinality = PerfectFinality
  { pfId :: Text
  , pfIsPerfect :: Bool
  , pfIsTotal :: Bool
  } deriving (Eq, Show)

-- | Complete conclusion type
type CompleteConclusion = PerfectFinality

-- | Total synthesis type
type TotalSynthesis = PerfectFinality

-- | Resolve absolutely
resolveAbsolutely :: PerfectFinality
resolveAbsolutely = PerfectFinality "resolution-001" True True