{-# LANGUAGE OverloadedStrings #-}
module Transcendence.EternalTranscendence
  ( BeyondLimits(..)
  , EternalTranscendence
  , InfiniteAscension
  , realizeTranscendence
  ) where

import Data.Text (Text)

-- | Eternal transcendence type
data BeyondLimits = BeyondLimits
  { blId :: Text
  , blIsBeyond :: Bool
  , blIsEternal :: Bool
  } deriving (Eq, Show)

-- | Eternal transcendence type
type EternalTranscendence = BeyondLimits

-- | Infinite ascension type
type InfiniteAscension = BeyondLimits

-- | Realize eternal transcendence
realizeTranscendence :: EternalTranscendence
realizeTranscendence = BeyondLimits "transcendence-001" True True