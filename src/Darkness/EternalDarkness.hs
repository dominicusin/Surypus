{-# LANGUAGE OverloadedStrings #-}
module Darkness.EternalDarkness
  ( InfiniteVoid(..)
  , EternalShadow
  , BoundlessDepth
  , embraceDarkness
  ) where

import Data.Text (Text)

-- | Eternal darkness type
data InfiniteVoid = InfiniteVoid
  { ivId :: Text
  , ivIsEternal :: Bool
  , ivIsBoundless :: Bool
  } deriving (Eq, Show)

-- | Eternal shadow type
type EternalShadow = InfiniteVoid

-- | Boundless depth type
type BoundlessDepth = InfiniteVoid

-- | Embrace eternal darkness
embraceDarkness :: EternalShadow
embraceDarkness = InfiniteVoid "darkness-001" True True