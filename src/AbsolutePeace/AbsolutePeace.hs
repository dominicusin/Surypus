{-# LANGUAGE OverloadedStrings #-}
module AbsolutePeace.AbsolutePeace
  ( UltimateSerenity(..)
  , CompleteTranquility
  , TotalHarmony
  , embodyAbsolutePeace
  ) where

import Data.Text (Text)

-- | Absolute peace type
data UltimateSerenity = UltimateSerenity
  { usId :: Text
  , usIsUltimate :: Bool
  , usIsTotal :: Bool
  } deriving (Eq, Show)

-- | Complete tranquility type
type CompleteTranquility = UltimateSerenity

-- | Total harmony type
type TotalHarmony = UltimateSerenity

-- | Embody absolute peace
embodyAbsolutePeace :: UltimateSerenity
embodyAbsolutePeace = UltimateSerenity "absolutepeace-001" True True