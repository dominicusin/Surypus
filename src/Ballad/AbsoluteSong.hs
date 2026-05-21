{-# LANGUAGE OverloadedStrings #-}
module Ballad.AbsoluteSong
  ( PerfectComposition(..)
  , UniversalChorus
  , InfiniteVerse
  , singSong
  ) where

import Data.Text (Text)

-- | Absolute song type
data PerfectComposition = PerfectComposition
  { pcId :: Text
  , pcIsPerfect :: Bool
  , pcIsUniversal :: Bool
  } deriving (Eq, Show)

-- | Universal chorus type
type UniversalChorus = PerfectComposition

-- | Infinite verse type
type InfiniteVerse = PerfectComposition

-- | Sing absolute song
singSong :: UniversalChorus
singSong = PerfectComposition "song-001" True True