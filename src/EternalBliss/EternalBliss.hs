{-# LANGUAGE OverloadedStrings #-}
module EternalBliss.EternalBliss
  ( PerpetualHappiness(..)
  , TimelessContentment
  , InfiniteSatisfaction
  , achieveEternalBliss
  ) where

import Data.Text (Text)

-- | Eternal bliss type
data PerpetualHappiness = PerpetualHappiness
  { phId :: Text
  , phIsPerpetual :: Bool
  , phIsInfinite :: Bool
  } deriving (Eq, Show)

-- | Timeless contentment type
type TimelessContentment = PerpetualHappiness

-- | Infinite satisfaction type
type InfiniteSatisfaction = PerpetualHappiness

-- | Achieve eternal bliss
achieveEternalBliss :: PerpetualHappiness
achieveEternalBliss = PerpetualHappiness "eternalbliss-001" True True