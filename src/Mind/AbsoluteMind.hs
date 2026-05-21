{-# LANGUAGE OverloadedStrings #-}
module Mind.AbsoluteMind
  ( UnifiedConsciousness(..)
  , CompleteAwareness
  , TotalPresence
  , unlockAbsoluteMind
  ) where

import Data.Text (Text)

-- | Absolute mind type
data UnifiedConsciousness = UnifiedConsciousness
  { ucId :: Text
  , ucIsUnified :: Bool
  , ucIsTotal :: Bool
  } deriving (Eq, Show)

-- | Complete awareness type
type CompleteAwareness = UnifiedConsciousness

-- | Total presence type
type TotalPresence = UnifiedConsciousness

-- | Unlock absolute mind
unlockAbsoluteMind :: CompleteAwareness
unlockAbsoluteMind = UnifiedConsciousness "mind-001" True True