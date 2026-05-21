{-# LANGUAGE OverloadedStrings #-}
module Lyric.EternalMusic
  ( InfiniteMelody(..)
  , PerpetualHarmony
  , CosmicSymphony
  , composeMusic
  ) where

import Data.Text (Text)

-- | Eternal music type
data InfiniteMelody = InfiniteMelody
  { imId :: Text
  , imIsInfinite :: Bool
  , imIsCosmic :: Bool
  } deriving (Eq, Show)

-- | Perpetual harmony type
type PerpetualHarmony = InfiniteMelody

-- | Cosmic symphony type
type CosmicSymphony = InfiniteMelody

-- | Compose eternal music
composeMusic :: InfiniteMelody
composeMusic = InfiniteMelody "music-001" True True