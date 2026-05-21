{-# LANGUAGE OverloadedStrings #-}
module Emergence.AbsoluteEmergence
  ( AbsoluteEmergence(..)
  , PureArising
  , FundamentalComingForth
  , manifestEmergence
  ) where

import Data.Text (Text)

-- | Absolute emergence type
data AbsoluteEmergence = AbsoluteEmergence
  { aeId :: Text
  , aeIsPure :: Bool
  , aeIsFundamental :: Bool
  } deriving (Eq, Show)

-- | Pure arising type
type PureArising = AbsoluteEmergence

-- | Fundamental coming forth type
type FundamentalComingForth = AbsoluteEmergence

-- | Manifest absolute emergence
manifestEmergence :: PureArising
manifestEmergence = AbsoluteEmergence "emergence-001" True True