{-# LANGUAGE OverloadedStrings #-}
module AbsoluteFinish.AbsoluteFinish
  ( UltimateConclusion(..)
  , FinalSynthesis
  , AbsoluteEnding
  , completeAbsolutely
  ) where

import Data.Text (Text)

-- | Absolute finish type
data UltimateConclusion = UltimateConclusion
  { ucId :: Text
  , ucIsUltimate :: Bool
  , ucIsAbsolute :: Bool
  } deriving (Eq, Show)

-- | Final synthesis type
type FinalSynthesis = UltimateConclusion

-- | Absolute ending type
type AbsoluteEnding = UltimateConclusion

-- | Complete absolutely
completeAbsolutely :: UltimateConclusion
completeAbsolutely = UltimateConclusion "finish-001" True True