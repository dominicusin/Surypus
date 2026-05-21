{-# LANGUAGE OverloadedStrings #-}
module Allegory.EternalBirth
  ( EternalBirth(..)
  , TimelessGenesis
  , PerpetualBeing
  , enactBirth
  ) where

import Data.Text (Text)

-- | Eternal birth type
data EternalBirth = EternalBirth
  { ebId :: Text
  , ebIsTimeless :: Bool
  , ebIsPerpetual :: Bool
  } deriving (Eq, Show)

-- | Timeless genesis type
type TimelessGenesis = EternalBirth

-- | Perpetual being type
type PerpetualBeing = EternalBirth

-- | Enact eternal birth
enactBirth :: TimelessGenesis
enactBirth = EternalBirth "birth-001" True True