{-# LANGUAGE OverloadedStrings #-}
module Omega.OmegaPoint
  ( OmegaConvergence(..)
  , UniversalMerge
  , AbsoluteSynthesis
  , reachOmega
  ) where

import Data.Text (Text)
import Data.Aeson (Value)

-- | Omega convergence type
data OmegaConvergence = OmegaConvergence
  { ocId :: Text
  , ocIsConverged :: Bool
  , ocIsAbsolute :: Bool
  } deriving (Eq, Show)

-- | Universal merge type
type UniversalMerge = Value -> Value

-- | Absolute synthesis type
type AbsoluteSynthesis = OmegaConvergence

-- | Reach omega point
reachOmega :: AbsoluteSynthesis
reachOmega = OmegaConvergence "omega-001" True True