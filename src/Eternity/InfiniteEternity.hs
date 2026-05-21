{-# LANGUAGE OverloadedStrings #-}
module Eternity.InfiniteEternity
  ( InfiniteAges(..)
  , TimelessDuration
  , EternalAges
  , embraceEternity
  ) where

import Data.Text (Text)

-- | Infinite eternity type
data InfiniteAges = InfiniteAges
  { iaId :: Text
  , iaIsTimeless :: Bool
  , iaIsInfinite :: Bool
  } deriving (Eq, Show)

-- | Timeless duration type
type TimelessDuration = InfiniteAges

-- | Eternal ages type
type EternalAges = InfiniteAges

-- | Embrace infinite eternity
embraceEternity :: TimelessDuration
embraceEternity = InfiniteAges "eternity-001" True True