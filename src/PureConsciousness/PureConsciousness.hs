{-# LANGUAGE OverloadedStrings #-}
module PureConsciousness.PureConsciousness
  ( UndividedAwareness(..)
  , PerfectPresence
  , AbsoluteNow
  , realizePureCon
  ) where

import Data.Text (Text)

-- | Pure consciousness type
data UndividedAwareness = UndividedAwareness
  { uaId :: Text
  , uaIsUndivided :: Bool
  , uaIsAbsolute :: Bool
  } deriving (Eq, Show)

-- | Perfect presence type
type PerfectPresence = UndividedAwareness

-- | Absolute now type
type AbsoluteNow = UndividedAwareness

-- | Realize pure consciousness
realizePureCon :: PerfectPresence
realizePureCon = UndividedAwareness "purecon-001" True True