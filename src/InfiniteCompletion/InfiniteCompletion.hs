{-# LANGUAGE OverloadedStrings #-}
module InfiniteCompletion.InfiniteCompletion
  ( BoundlessFinishing(..)
  , EndlessCulmination
  , UnlimitedResolution
  , finalizeInfinite
  ) where

import Data.Text (Text)

-- | Infinite completion type
data BoundlessFinishing = BoundlessFinishing
  { bfId :: Text
  , bfIsBoundless :: Bool
  , bfIsUnlimited :: Bool
  } deriving (Eq, Show)

-- | Endless culmination type
type EndlessCulmination = BoundlessFinishing

-- | Unlimited resolution type
type UnlimitedResolution = BoundlessFinishing

-- | Finalize infinite
finalizeInfinite :: BoundlessFinishing
finalizeInfinite = BoundlessFinishing "completion-001" True True