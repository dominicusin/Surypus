{-# LANGUAGE OverloadedStrings #-}
module FinalJoy.FinalJoy
  ( ConsummateHappiness(..)
  , IneffableContentment
  , TranscendentSatisfaction
  , embodyFinalJoy
  ) where

import Data.Text (Text)

-- | Final joy type
data ConsummateHappiness = ConsummateHappiness
  { chId :: Text
  , chIsConsummate :: Bool
  , chIsTranscendent :: Bool
  } deriving (Eq, Show)

-- | Ineffable contentment type
type IneffableContentment = ConsummateHappiness

-- | Transcendent satisfaction type
type TranscendentSatisfaction = ConsummateHappiness

-- | Embody final joy
embodyFinalJoy :: ConsummateHappiness
embodyFinalJoy = ConsummateHappiness "finaljoy-001" True True