{-# LANGUAGE OverloadedStrings #-}
module Tranquility.EternalCalm
  ( InfiniteSerenity(..)
  , PerfectPeace
  , AbsoluteStillness
  , findCalm
  ) where

import Data.Text (Text)

-- | Eternal calm type
data InfiniteSerenity = InfiniteSerenity
  { isId :: Text
  , isIsInfinite :: Bool
  , isIsPerfect :: Bool
  } deriving (Eq, Show)

-- | Perfect peace type
type PerfectPeace = InfiniteSerenity

-- | Absolute stillness type
type AbsoluteStillness = InfiniteSerenity

-- | Find eternal calm
findCalm :: PerfectPeace
findCalm = InfiniteSerenity "calm-001" True True