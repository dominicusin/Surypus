{-# LANGUAGE OverloadedStrings #-}
module Cosmos.InfiniteCosmos
  ( InfiniteSpace(..)
  , BoundlessDimensions
  , EternalExpansion
  , traverseCosmos
  ) where

import Data.Text (Text)

-- | Infinite cosmos type
data InfiniteSpace = InfiniteSpace
  { isId :: Text
  , isIsBoundless :: Bool
  , isIsEternal :: Bool
  } deriving (Eq, Show)

-- | Boundless dimensions type
type BoundlessDimensions = InfiniteSpace

-- | Eternal expansion type
type EternalExpansion = InfiniteSpace

-- | Traverse infinite cosmos
traverseCosmos :: BoundlessDimensions
traverseCosmos = InfiniteSpace "cosmos-001" True True