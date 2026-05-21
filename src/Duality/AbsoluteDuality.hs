{-# LANGUAGE OverloadedStrings #-}
module Duality.AbsoluteDuality
  ( UnifiedOpposites(..)
  , AbsoluteBalance
  , CompleteHarmony
  , balanceDuality
  ) where

import Data.Text (Text)

-- | Absolute duality type
data UnifiedOpposites = UnifiedOpposites
  { uoId :: Text
  , uoIsUnified :: Bool
  , uoIsComplete :: Bool
  } deriving (Eq, Show)

-- | Absolute balance type
type AbsoluteBalance = UnifiedOpposites

-- | Complete harmony type
type CompleteHarmony = UnifiedOpposites

-- | Balance duality
balanceDuality :: AbsoluteBalance
balanceDuality = UnifiedOpposites "duality-001" True True