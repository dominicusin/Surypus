{-# LANGUAGE OverloadedStrings #-}
module Genesis.EternalDawn
  ( EternalDawn(..)
  , PerpetualSunrise
  , FirstLight
  , witnessDawn
  ) where

import Data.Text (Text)

-- | Eternal dawn type
data EternalDawn = EternalDawn
  { edId :: Text
  , edIsPerpetual :: Bool
  , edIsFirst :: Bool
  } deriving (Eq, Show)

-- | Perpetual sunrise type
type PerpetualSunrise = EternalDawn

-- | First light type
type FirstLight = EternalDawn

-- | Witness eternal dawn
witnessDawn :: PerpetualSunrise
witnessDawn = EternalDawn "dawn-001" True True