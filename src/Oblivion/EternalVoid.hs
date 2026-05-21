{-# LANGUAGE OverloadedStrings #-}
module Oblivion.EternalVoid
  ( InfiniteEmptiness(..)
  , EternalNothingness
  , BoundlessSilence
  , embraceVoid
  ) where

import Data.Text (Text)

-- | Eternal void type
data InfiniteEmptiness = InfiniteEmptiness
  { ieId :: Text
  , ieIsInfinite :: Bool
  , ieIsEternal :: Bool
  } deriving (Eq, Show)

-- | Eternal nothingness type
type EternalNothingness = InfiniteEmptiness

-- | Boundless silence type
type BoundlessSilence = InfiniteEmptiness

-- | Embrace eternal void
embraceVoid :: EternalNothingness
embraceVoid = InfiniteEmptiness "void-001" True True