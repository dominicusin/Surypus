{-# LANGUAGE OverloadedStrings #-}
module Absolute.AbsoluteSystems
  ( AbsoluteTruth(..)
  , PerfectSystem
  , InfiniteOptimization
  , achievePerfection
  ) where

import Data.Text (Text)
import Data.Aeson (Value)

-- | Absolute truth type
data AbsoluteTruth = AbsoluteTruth
  { atId :: Text
  , atIsPerfect :: Bool
  , atIsComplete :: Bool
  } deriving (Eq, Show)

-- | Perfect system type
type PerfectSystem = AbsoluteTruth

-- | Infinite optimization type
type InfiniteOptimization = Value -> Value

-- | Achieve perfection
achievePerfection :: InfiniteOptimization
achievePerfection input = input