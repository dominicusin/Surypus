{-# LANGUAGE OverloadedStrings #-}
module AbsoluteEnlightenmentPt2.AbsoluteEnlightenmentPt2
  ( UltimateAwakening(..)
  , FinalIllumination
  , CompleteUnderstanding
  , realizeAbsoluteEnlightenment
  ) where

import Data.Text (Text)

-- | Absolute enlightenment type
data UltimateAwakening = UltimateAwakening
  { uaId :: Text
  , uaIsUltimate :: Bool
  , uaIsComplete :: Bool
  } deriving (Eq, Show)

-- | Final illumination type
type FinalIllumination = UltimateAwakening

-- | Complete understanding type
type CompleteUnderstanding = UltimateAwakening

-- | Realize absolute enlightenment
realizeAbsoluteEnlightenment :: UltimateAwakening
realizeAbsoluteEnlightenment = UltimateAwakening "absoluteenlightenment-001" True True