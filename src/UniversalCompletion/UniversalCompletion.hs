{-# LANGUAGE OverloadedStrings #-}
module UniversalCompletion.UniversalCompletion
  ( InfiniteSynthesis(..)
  , TotalIntegration
  , AbsoluteFinish
  , completeUniversally
  ) where

import Data.Text (Text)

-- | Universal completion type
data InfiniteSynthesis = InfiniteSynthesis
  { isId :: Text
  , isIsInfinite :: Bool
  , isIsAbsolute :: Bool
  } deriving (Eq, Show)

-- | Total integration type
type TotalIntegration = InfiniteSynthesis

-- | Absolute finish type
type AbsoluteFinish = InfiniteSynthesis

-- | Complete universally
completeUniversally :: InfiniteSynthesis
completeUniversally = InfiniteSynthesis "universalcompletion-001" True True