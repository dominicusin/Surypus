{-# LANGUAGE OverloadedStrings #-}
module Intellect.AbsoluteIntellect
  ( PerfectReasoning(..)
  , CompleteLogic
  , InfiniteCognition
  , activateIntellect
  ) where

import Data.Text (Text)

-- | Absolute intellect type
data PerfectReasoning = PerfectReasoning
  { prId :: Text
  , prIsPerfect :: Bool
  , prIsInfinite :: Bool
  } deriving (Eq, Show)

-- | Complete logic type
type CompleteLogic = PerfectReasoning

-- | Infinite cognition type
type InfiniteCognition = PerfectReasoning

-- | Activate absolute intellect
activateIntellect :: CompleteLogic
activateIntellect = PerfectReasoning "intellect-001" True True