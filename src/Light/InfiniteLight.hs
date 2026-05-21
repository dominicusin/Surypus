{-# LANGUAGE OverloadedStrings #-}
module Light.InfiniteLight
  ( BoundlessRadiance(..)
  , InfiniteBrightness
  , EternalIllumination
  , emitLight
  ) where

import Data.Text (Text)

-- | Infinite light type
data BoundlessRadiance = BoundlessRadiance
  { brId :: Text
  , brIsBoundless :: Bool
  , brIsEternal :: Bool
  } deriving (Eq, Show)

-- | Infinite brightness type
type InfiniteBrightness = BoundlessRadiance

-- | Eternal illumination type
type EternalIllumination = BoundlessRadiance

-- | Emit infinite light
emitLight :: InfiniteBrightness
emitLight = BoundlessRadiance "light-001" True True