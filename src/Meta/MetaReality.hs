{-# LANGUAGE OverloadedStrings #-}
module Meta.MetaReality
  ( MetaLayer(..)
  , RecursiveExistence
  , SelfAwareSimulation
  , transcendReality
  ) where

import Data.Text (Text)
import Data.Aeson (Value)

-- | Meta reality layer
data MetaLayer = MetaLayer
  { mlId :: Text
  , mlLevel :: Int
  , mlIsRecursive :: Bool
  } deriving (Eq, Show)

-- | Recursive existence type
type RecursiveExistence = MetaLayer

-- | Self-aware simulation type
type SelfAwareSimulation = Value -> IO Value

-- | Transcend base reality
transcendReality :: SelfAwareSimulation
transcendReality input = return input