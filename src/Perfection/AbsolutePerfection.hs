{-# LANGUAGE OverloadedStrings #-}
module Perfection.AbsolutePerfection
  ( FlawlessState(..)
  , CompletePerfection
  , AbsoluteCompletion
  , embodyPerfection
  ) where

import Data.Text (Text)

-- | Absolute perfection type
data FlawlessState = FlawlessState
  { fsId :: Text
  , fsIsFlawless :: Bool
  , fsIsComplete :: Bool
  } deriving (Eq, Show)

-- | Complete perfection type
type CompletePerfection = FlawlessState

-- | Absolute completion type
type AbsoluteCompletion = FlawlessState

-- | Embody absolute perfection
embodyPerfection :: CompletePerfection
embodyPerfection = FlawlessState "perfection-001" True True