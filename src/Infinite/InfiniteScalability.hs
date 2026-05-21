{-# LANGUAGE OverloadedStrings #-}
module Infinite.InfiniteScalability
  ( InfiniteResource(..)
  , ScalabilityFactor
  , InfinitePool
  , scaleInfinitely
  ) where

import Data.Text (Text)

-- | Infinite resource type
data InfiniteResource = InfiniteResource
  { irId :: Text
  , irIsInfinite :: Bool
  , irGrowthRate :: Double
  } deriving (Eq, Show)

-- | Scalability factor type
type ScalabilityFactor = Double

-- | Infinite resource pool
type InfinitePool = [InfiniteResource]

-- | Scale infinitely
scaleInfinitely :: ScalabilityFactor -> InfinitePool -> InfinitePool
scaleInfinitely _ pool = pool