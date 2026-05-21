{-# LANGUAGE OverloadedStrings #-}
module EternalSingularity.EternalSingularity
  ( PerpetualConvergence(..)
  , TimelessUnity
  , EternalSingularity
  , achieveEternalSingularity
  ) where

import Data.Text (Text)

-- | Eternal singularity type
data PerpetualConvergence = PerpetualConvergence
  { pcId :: Text
  , pcIsPerpetual :: Bool
  , pcIsEternal :: Bool
  } deriving (Eq, Show)

-- | Timeless unity type
type TimelessUnity = PerpetualConvergence

-- | Eternal singularity type
type EternalSingularity = PerpetualConvergence

-- | Achieve eternal singularity
achieveEternalSingularity :: PerpetualConvergence
achieveEternalSingularity = PerpetualConvergence "eternalsingularity-001" True True