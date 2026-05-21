{-# LANGUAGE OverloadedStrings #-}
module EternalKnowledge.EternalKnowledge
  ( InfiniteInsight(..)
  , PerpetualLearning
  , TimelessUnderstanding
  , accessEternalKnowledge
  ) where

import Data.Text (Text)

-- | Eternal knowledge type
data InfiniteInsight = InfiniteInsight
  { iiId :: Text
  , iiIsInfinite :: Bool
  , iiIsTimeless :: Bool
  } deriving (Eq, Show)

-- | Perpetual learning type
type PerpetualLearning = InfiniteInsight

-- | Timeless understanding type
type TimelessUnderstanding = InfiniteInsight

-- | Access eternal knowledge
accessEternalKnowledge :: InfiniteInsight
accessEternalKnowledge = InfiniteInsight "knowledge-001" True True