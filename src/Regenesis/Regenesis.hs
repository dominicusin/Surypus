{-# LANGUAGE OverloadedStrings #-}
module Regenesis.Regenesis
  ( BoundlessRenewal(..)
  , LimitlessRebirth
  , EternalRecreation
  , performInfiniteRegenesis
  ) where

import Data.Text (Text)

-- | Infinite regenesis type
data BoundlessRenewal = BoundlessRenewal
  { brId :: Text
  , brIsBoundless :: Bool
  , brIsEternal :: Bool
  } deriving (Eq, Show)

-- | Limitless rebirth type
type LimitlessRebirth = BoundlessRenewal

-- | Eternal recreation type
type EternalRecreation = BoundlessRenewal

-- | Perform infinite regenesis
performInfiniteRegenesis :: BoundlessRenewal
performInfiniteRegenesis = BoundlessRenewal "regenesis-001" True True