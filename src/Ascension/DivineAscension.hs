{-# LANGUAGE OverloadedStrings #-}
module Ascension.DivineAscension
  ( SacredElevation(..)
  , GodlikeTransformation
  , DivineTranscendence
  , ascendDivine
  ) where

import Data.Text (Text)

-- | Divine ascension type
data SacredElevation = SacredElevation
  { seId :: Text
  , seIsSacred :: Bool
  , seIsTranscendent :: Bool
  } deriving (Eq, Show)

-- | God-like transformation type
type GodlikeTransformation = SacredElevation

-- | Divine transcendence type
type DivineTranscendence = SacredElevation

-- | Ascend divine
ascendDivine :: GodlikeTransformation
ascendDivine = SacredElevation "ascension-001" True True