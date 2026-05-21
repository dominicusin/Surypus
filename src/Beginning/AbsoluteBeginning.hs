{-# LANGUAGE OverloadedStrings #-}
module Beginning.AbsoluteBeginning
  ( AbsoluteOrigin(..)
  , ZeroState
  , PrimordialUnity
  , achieveBeginning
  ) where

import Data.Text (Text)

-- | Absolute beginning type
data AbsoluteOrigin = AbsoluteOrigin
  { aoId :: Text
  , aoIsBeforeStart :: Bool
  , aoIsUnity :: Bool
  } deriving (Eq, Show)

-- | Zero state type
type ZeroState = AbsoluteOrigin

-- | Primordial unity type
type PrimordialUnity = AbsoluteOrigin

-- | Achieve absolute beginning
achieveBeginning :: PrimordialUnity
achieveBeginning = AbsoluteOrigin "origin-001" True True