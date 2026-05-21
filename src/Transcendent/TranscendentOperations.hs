{-# LANGUAGE OverloadedStrings #-}
module Transcendent.TranscendentOperations
  ( TranscendentState(..)
  , TransLogic
  , BeyondPhysical
  , transcendCompute
  ) where

import Data.Text (Text)
import Data.Aeson (Value)

-- | Transcendent state beyond physical bounds
data TranscendentState = TranscendentState
  { tsId :: Text
  , tsBeyondLimits :: Bool
  , tsInfinite :: Bool
  } deriving (Eq, Show)

-- | Transcendent logic type
type TransLogic = Value -> IO Value

-- | Beyond physical computation marker
type BeyondPhysical = TranscendentState

-- | Perform transcendent computation
transcendCompute :: TransLogic
transcendCompute input = return input