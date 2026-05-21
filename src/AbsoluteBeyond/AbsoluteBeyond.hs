{-# LANGUAGE OverloadedStrings #-}
module AbsoluteBeyond.AbsoluteBeyond
  ( UltimateTranscendence(..)
  , FinalBeyond
  , CompleteSupremacy
  , realizeAbsoluteBeyond
  ) where

import Data.Text (Text)

-- | Absolute beyond type
data UltimateTranscendence = UltimateTranscendence
  { utId :: Text
  , utIsUltimate :: Bool
  , utIsComplete :: Bool
  } deriving (Eq, Show)

-- | Final beyond type
type FinalBeyond = UltimateTranscendence

-- | Complete supremacy type
type CompleteSupremacy = UltimateTranscendence

-- | Realize absolute beyond
realizeAbsoluteBeyond :: UltimateTranscendence
realizeAbsoluteBeyond = UltimateTranscendence "absolutebeyond-001" True True