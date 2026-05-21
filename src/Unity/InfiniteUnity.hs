{-# LANGUAGE OverloadedStrings #-}
module Unity.InfiniteUnity
  ( TotalIntegration(..)
  , UniversalSynthesis
  , InfiniteConvergence
  , uniteInfinitely
  ) where

import Data.Text (Text)

-- | Infinite unity type
data TotalIntegration = TotalIntegration
  { tiId :: Text
  , tiIsTotal :: Bool
  , tiIsInfinite :: Bool
  } deriving (Eq, Show)

-- | Universal synthesis type
type UniversalSynthesis = TotalIntegration

-- | Infinite convergence type
type InfiniteConvergence = TotalIntegration

-- | Unite infinitely
uniteInfinitely :: TotalIntegration
uniteInfinitely = TotalIntegration "unity-001" True True