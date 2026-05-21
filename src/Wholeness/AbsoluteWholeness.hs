{-# LANGUAGE OverloadedStrings #-}
module Wholeness.AbsoluteWholeness
  ( PerfectCompletion(..)
  , UniversalFulfillment
  , InfinitePerfection
  , achieveWholeness
  ) where

import Data.Text (Text)

-- | Absolute wholeness type
data PerfectCompletion = PerfectCompletion
  { pcId :: Text
  , pcIsPerfect :: Bool
  , pcIsInfinite :: Bool
  } deriving (Eq, Show)

-- | Universal fulfillment type
type UniversalFulfillment = PerfectCompletion

-- | Infinite perfection type
type InfinitePerfection = PerfectCompletion

-- | Achieve absolute wholeness
achieveWholeness :: PerfectCompletion
achieveWholeness = PerfectCompletion "wholeness-001" True True