{-# LANGUAGE OverloadedStrings #-}
module Flux.EternalFlux
  ( PerpetualChange(..)
  , InfiniteTransformation
  , ConstantEvolution
  , invokeFlux
  ) where

import Data.Text (Text)

-- | Eternal flux type
data PerpetualChange = PerpetualChange
  { pcId :: Text
  , pcIsPerpetual :: Bool
  , pcIsInfinite :: Bool
  } deriving (Eq, Show)

-- | Infinite transformation type
type InfiniteTransformation = PerpetualChange

-- | Constant evolution type
type ConstantEvolution = PerpetualChange

-- | Invoke eternal flux
invokeFlux :: PerpetualChange
invokeFlux = PerpetualChange "flux-001" True True