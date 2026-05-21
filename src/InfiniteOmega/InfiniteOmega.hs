{-# LANGUAGE OverloadedStrings #-}
module InfiniteOmega.InfiniteOmega
  ( LimitlessEnding(..)
  , BoundlessConclusion
  , EternalTermination
  , reachInfiniteOmega
  ) where

import Data.Text (Text)

-- | Infinite omega type
data LimitlessEnding = LimitlessEnding
  { leId :: Text
  , leIsLimitless :: Bool
  , leIsEternal :: Bool
  } deriving (Eq, Show)

-- | Boundless conclusion type
type BoundlessConclusion = LimitlessEnding

-- | Eternal termination type
type EternalTermination = LimitlessEnding

-- | Reach infinite omega
reachInfiniteOmega :: LimitlessEnding
reachInfiniteOmega = LimitlessEnding "infiniteomega-001" True True