{-# LANGUAGE OverloadedStrings #-}
module InfiniteEcstasy.InfiniteEcstasy
  ( RapturousTranscendence(..)
  , ExultantElevation
  , JubilantAscension
  , achieveInfiniteEcstasy
  ) where

import Data.Text (Text)

-- | Infinite ecstasy type
data RapturousTranscendence = RapturousTranscendence
  { rtId :: Text
  , rtIsRapturous :: Bool
  , rtIsJubilant :: Bool
  } deriving (Eq, Show)

-- | Exultant elevation type
type ExultantElevation = RapturousTranscendence

-- | Jubilant ascension type
type JubilantAscension = RapturousTranscendence

-- | Achieve infinite ecstasy
achieveInfiniteEcstasy :: RapturousTranscendence
achieveInfiniteEcstasy = RapturousTranscendence "infiniteecstasy-001" True True