{-# LANGUAGE OverloadedStrings #-}
module Symphony.EternalHarmony
  ( InfiniteConcord(..)
  , PerfectBalance
  , AbsoluteUnity
  , achieveHarmony
  ) where

import Data.Text (Text)

-- | Eternal harmony type
data InfiniteConcord = InfiniteConcord
  { icId :: Text
  , icIsInfinite :: Bool
  , icIsAbsolute :: Bool
  } deriving (Eq, Show)

-- | Perfect balance type
type PerfectBalance = InfiniteConcord

-- | Absolute unity type
type AbsoluteUnity = InfiniteConcord

-- | Achieve eternal harmony
achieveHarmony :: PerfectBalance
achieveHarmony = InfiniteConcord "harmony-001" True True