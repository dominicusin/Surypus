{-# LANGUAGE OverloadedStrings #-}
module Clarity.EternalSight
  ( InfiniteClarity(..)
  , PerpetualFocus
  , TimelessInsight
  , gazeEternal
  ) where

import Data.Text (Text)

-- | Eternal sight type
data InfiniteClarity = InfiniteClarity
  { icId :: Text
  , icIsInfinite :: Bool
  , icIsTimeless :: Bool
  } deriving (Eq, Show)

-- | Perpetual focus type
type PerpetualFocus = InfiniteClarity

-- | Timeless insight type
type TimelessInsight = InfiniteClarity

-- | Gaze eternal
gazeEternal :: InfiniteClarity
gazeEternal = InfiniteClarity "sight-001" True True