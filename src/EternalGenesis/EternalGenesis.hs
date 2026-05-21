{-# LANGUAGE OverloadedStrings #-}
module EternalGenesis.EternalGenesis
  ( TimelessBeginning(..)
  , PerpetualCreation
  , InfiniteOrigination
  , igniteEternalGenesis
  ) where

import Data.Text (Text)

-- | Eternal genesis type
data TimelessBeginning = TimelessBeginning
  { tbId :: Text
  , tbIsTimeless :: Bool
  , tbIsInfinite :: Bool
  } deriving (Eq, Show)

-- | Perpetual creation type
type PerpetualCreation = TimelessBeginning

-- | Infinite origination type
type InfiniteOrigination = TimelessBeginning

-- | Ignite eternal genesis
igniteEternalGenesis :: TimelessBeginning
igniteEternalGenesis = TimelessBeginning "eternalgenesis-001" True True