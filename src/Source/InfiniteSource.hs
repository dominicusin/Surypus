{-# LANGUAGE OverloadedStrings #-}
module Source.InfiniteSource
  ( InfiniteSource(..)
  , SelfCreating
  , BoundlessCreation
  , accessSource
  ) where

import Data.Text (Text)
import Data.Aeson (Value)

-- | Infinite source type
data InfiniteSource = InfiniteSource
  { isId :: Text
  , isIsInfinite :: Bool
  , isCreatesItself :: Bool
  } deriving (Eq, Show)

-- | Self-creating type
type SelfCreating = InfiniteSource

-- | Boundless creation type
type BoundlessCreation = Value -> IO Value

-- | Access infinite source
accessSource :: BoundlessCreation
accessSource input = return input