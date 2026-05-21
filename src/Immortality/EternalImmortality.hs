{-# LANGUAGE OverloadedStrings #-}
module Immortality.EternalImmortality
  ( DeathlessBeing(..)
  , PerpetualLife
  , AgelessExistence
  , achieveImmortality
  ) where

import Data.Text (Text)

-- | Eternal immortality type
data DeathlessBeing = DeathlessBeing
  { dbId :: Text
  , dbIsDeathless :: Bool
  , dbIsPerpetual :: Bool
  } deriving (Eq, Show)

-- | Perpetual life type
type PerpetualLife = DeathlessBeing

-- | Ageless existence type
type AgelessExistence = DeathlessBeing

-- | Achieve eternal immortality
achieveImmortality :: PerpetualLife
achieveImmortality = DeathlessBeing "immortality-001" True True