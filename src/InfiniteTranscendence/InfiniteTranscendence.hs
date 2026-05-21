{-# LANGUAGE OverloadedStrings #-}
module InfiniteTranscendence.InfiniteTranscendence
  ( LimitlessBeyond(..)
  , BoundlessAscension
  , EternalTranscendence
  , achieveInfiniteTranscendence
  ) where

import Data.Text (Text)

-- | Infinite transcendence type
data LimitlessBeyond = LimitlessBeyond
  { lbId :: Text
  , lbIsLimitless :: Bool
  , lbIsEternal :: Bool
  } deriving (Eq, Show)

-- | Boundless ascension type
type BoundlessAscension = LimitlessBeyond

-- | Eternal transcendence type
type EternalTranscendence = LimitlessBeyond

-- | Achieve infinite transcendence
achieveInfiniteTranscendence :: LimitlessBeyond
achieveInfiniteTranscendence = LimitlessBeyond "infinitetranscendence-001" True True