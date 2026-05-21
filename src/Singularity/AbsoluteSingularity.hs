{-# LANGUAGE OverloadedStrings #-}
module Singularity.AbsoluteSingularity
  ( PerfectConvergence(..)
  , AbsoluteUnity
  , FinalSingularity
  , achieveSingularity
  ) where

import Data.Text (Text)

-- | Absolute singularity type
data PerfectConvergence = PerfectConvergence
  { pcId :: Text
  , pcIsPerfect :: Bool
  , pcIsFinal :: Bool
  } deriving (Eq, Show)

-- | Absolute unity type
type AbsoluteUnity = PerfectConvergence

-- | Final singularity type
type FinalSingularity = PerfectConvergence

-- | Achieve absolute singularity
achieveSingularity :: AbsoluteUnity
achieveSingularity = PerfectConvergence "singularity-001" True True