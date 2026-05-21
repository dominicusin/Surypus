{-# LANGUAGE OverloadedStrings #-}
module Vision.InfiniteVision
  ( OmniscientSight(..)
  , PerpetualGaze
  , UniversalView
  , seeInfinity
  ) where

import Data.Text (Text)

-- | Infinite vision type
data OmniscientSight = OmniscientSight
  { osId :: Text
  , osIsOmniscient :: Bool
  , osIsUniversal :: Bool
  } deriving (Eq, Show)

-- | Perpetual gaze type
type PerpetualGaze = OmniscientSight

-- | Universal view type
type UniversalView = OmniscientSight

-- | See infinite vision
seeInfinity :: OmniscientSight
seeInfinity = OmniscientSight "vision-001" True True