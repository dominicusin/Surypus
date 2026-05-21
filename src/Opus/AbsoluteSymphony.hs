{-# LANGUAGE OverloadedStrings #-}
module Opus.AbsoluteSymphony
  ( CosmicOrchestration(..)
  , UniversalConcerto
  , InfiniteMelody
  , conductSymphony
  ) where

import Data.Text (Text)

-- | Absolute symphony type
data CosmicOrchestration = CosmicOrchestration
  { coId :: Text
  , coIsCosmic :: Bool
  , coIsInfinite :: Bool
  } deriving (Eq, Show)

-- | Universal concerto type
type UniversalConcerto = CosmicOrchestration

-- | Infinite melody type
type InfiniteMelody = CosmicOrchestration

-- | Conduct absolute symphony
conductSymphony :: UniversalConcerto
conductSymphony = CosmicOrchestration "symphony-001" True True