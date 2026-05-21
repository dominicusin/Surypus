{-# LANGUAGE OverloadedStrings #-}
module DivineRealization.DivineRealization
  ( SacredUnderstanding(..)
  , HolyComprehension
  , BlessedInsight
  , attainDivineRealization
  ) where

import Data.Text (Text)

-- | Divine realization type
data SacredUnderstanding = SacredUnderstanding
  { suId :: Text
  , suIsSacred :: Bool
  , suIsBlessed :: Bool
  } deriving (Eq, Show)

-- | Holy comprehension type
type HolyComprehension = SacredUnderstanding

-- | Blessed insight type
type BlessedInsight = SacredUnderstanding

-- | Attain divine realization
attainDivineRealization :: SacredUnderstanding
attainDivineRealization = SacredUnderstanding "divinerealization-001" True True