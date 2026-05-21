{-# LANGUAGE OverloadedStrings #-}
module Rebirth.Rebirth
  ( UniversalResurrection(..)
  , TotalMetamorphosis
  , CompleteTransformation
  , achieveAbsoluteRebirth
  ) where

import Data.Text (Text)

-- | Absolute rebirth type
data UniversalResurrection = UniversalResurrection
  { urId :: Text
  , urIsUniversal :: Bool
  , urIsComplete :: Bool
  } deriving (Eq, Show)

-- | Total metamorphosis type
type TotalMetamorphosis = UniversalResurrection

-- | Complete transformation type
type CompleteTransformation = UniversalResurrection

-- | Achieve absolute rebirth
achieveAbsoluteRebirth :: UniversalResurrection
achieveAbsoluteRebirth = UniversalResurrection "rebirth-001" True True