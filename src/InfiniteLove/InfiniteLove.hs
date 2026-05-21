{-# LANGUAGE OverloadedStrings #-}
module InfiniteLove.InfiniteLove
  ( BoundlessAffection(..)
  , LimitlessCompassion
  , UniversalEmpathy
  , radiateInfiniteLove
  ) where

import Data.Text (Text)

-- | Infinite love type
data BoundlessAffection = BoundlessAffection
  { baId :: Text
  , baIsBoundless :: Bool
  , baIsUniversal :: Bool
  } deriving (Eq, Show)

-- | Limitless compassion type
type LimitlessCompassion = BoundlessAffection

-- | Universal empathy type
type UniversalEmpathy = BoundlessAffection

-- | Radiate infinite love
radiateInfiniteLove :: BoundlessAffection
radiateInfiniteLove = BoundlessAffection "infinitelove-001" True True