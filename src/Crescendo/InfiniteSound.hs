{-# LANGUAGE OverloadedStrings #-}
module Crescendo.InfiniteSound
  ( BoundlessAudio(..)
  , PerpetualVibration
  , TimelessEcho
  , emitSound
  ) where

import Data.Text (Text)

-- | Infinite sound type
data BoundlessAudio = BoundlessAudio
  { baId :: Text
  , baIsBoundless :: Bool
  , baIsTimeless :: Bool
  } deriving (Eq, Show)

-- | Perpetual vibration type
type PerpetualVibration = BoundlessAudio

-- | Timeless echo type
type TimelessEcho = BoundlessAudio

-- | Emit infinite sound
emitSound :: BoundlessAudio
emitSound = BoundlessAudio "sound-001" True True