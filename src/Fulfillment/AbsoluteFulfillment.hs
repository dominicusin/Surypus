{-# LANGUAGE OverloadedStrings #-}
module Fulfillment.AbsoluteFulfillment
  ( PerfectSatisfaction(..)
  , CompleteRealization
  , InfiniteCompletion
  , fulfillAbsolutely
  ) where

import Data.Text (Text)

-- | Absolute fulfillment type
data PerfectSatisfaction = PerfectSatisfaction
  { psId :: Text
  , psIsPerfect :: Bool
  , psIsInfinite :: Bool
  } deriving (Eq, Show)

-- | Complete realization type
type CompleteRealization = PerfectSatisfaction

-- | Infinite completion type
type InfiniteCompletion = PerfectSatisfaction

-- | Fulfill absolutely
fulfillAbsolutely :: PerfectSatisfaction
fulfillAbsolutely = PerfectSatisfaction "fulfillment-001" True True