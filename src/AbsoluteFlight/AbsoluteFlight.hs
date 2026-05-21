{-# LANGUAGE OverloadedStrings #-}
module AbsoluteFlight.AbsoluteFlight
  ( SupremeElevation(..)
  , PeakTranscendence
  , FinalAscension
  , achieveAbsoluteFlight
  ) where

import Data.Text (Text)

-- | Absolute flight type
data SupremeElevation = SupremeElevation
  { seId :: Text
  , seIsSupreme :: Bool
  , seIsFinal :: Bool
  } deriving (Eq, Show)

-- | Peak transcendence type
type PeakTranscendence = SupremeElevation

-- | Final ascension type
type FinalAscension = SupremeElevation

-- | Achieve absolute flight
achieveAbsoluteFlight :: SupremeElevation
achieveAbsoluteFlight = SupremeElevation "absoluteflight-001" True True