{-# LANGUAGE OverloadedStrings #-}
module EternalCompassion.EternalCompassion
  ( PerpetualKindness(..)
  , TimelessMercy
  , InfiniteBenevolence
  , embodyEternalCompassion
  ) where

import Data.Text (Text)

-- | Eternal compassion type
data PerpetualKindness = PerpetualKindness
  { pkId :: Text
  , pkIsPerpetual :: Bool
  , pkIsInfinite :: Bool
  } deriving (Eq, Show)

-- | Timeless mercy type
type TimelessMercy = PerpetualKindness

-- | Infinite benevolence type
type InfiniteBenevolence = PerpetualKindness

-- | Embody eternal compassion
embodyEternalCompassion :: PerpetualKindness
embodyEternalCompassion = PerpetualKindness "eternalcompassion-001" True True