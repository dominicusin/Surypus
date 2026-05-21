{-# LANGUAGE OverloadedStrings #-}
module Multiverse.EternalMultiverse
  ( EternalBranches(..)
  , ParallelRealities
  , InfinitePossibilities
  , exploreMultiverse
  ) where

import Data.Text (Text)

-- | Eternal multiverse type
data EternalBranches = EternalBranches
  { ebId :: Text
  , ebIsParallel :: Bool
  , ebIsInfinite :: Bool
  } deriving (Eq, Show)

-- | Parallel realities type
type ParallelRealities = EternalBranches

-- | Infinite possibilities type
type InfinitePossibilities = EternalBranches

-- | Explore eternal multiverse
exploreMultiverse :: ParallelRealities
exploreMultiverse = EternalBranches "multiverse-001" True True