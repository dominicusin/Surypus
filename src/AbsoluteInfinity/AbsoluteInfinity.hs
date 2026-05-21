{-# LANGUAGE OverloadedStrings #-}
module AbsoluteInfinity.AbsoluteInfinity
  ( UltimateBoundlessness(..)
  , FinalLimitlessness
  , TotalEndlessness
  , realizeAbsoluteInfinity
  ) where

import Data.Text (Text)

-- | Absolute infinity type
data UltimateBoundlessness = UltimateBoundlessness
  { ubId :: Text
  , ubIsUltimate :: Bool
  , ubIsTotal :: Bool
  } deriving (Eq, Show)

-- | Final limitlessness type
type FinalLimitlessness = UltimateBoundlessness

-- | Total endlessness type
type TotalEndlessness = UltimateBoundlessness

-- | Realize absolute infinity
realizeAbsoluteInfinity :: UltimateBoundlessness
realizeAbsoluteInfinity = UltimateBoundlessness "absoluteinfinity-001" True True