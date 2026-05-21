{-# LANGUAGE OverloadedStrings #-}
module UniversalFinish.UniversalFinish
  ( InfiniteCulmination(..)
  , EternalResolution
  , AbsoluteCompletion
  , finishUniversally
  ) where

import Data.Text (Text)

-- | Universal finish type
data InfiniteCulmination = InfiniteCulmination
  { icId :: Text
  , icIsInfinite :: Bool
  , icIsAbsolute :: Bool
  } deriving (Eq, Show)

-- | Eternal resolution type
type EternalResolution = InfiniteCulmination

-- | Absolute completion type
type AbsoluteCompletion = InfiniteCulmination

-- | Finish universally
finishUniversally :: InfiniteCulmination
finishUniversally = InfiniteCulmination "universalfinish-001" True True