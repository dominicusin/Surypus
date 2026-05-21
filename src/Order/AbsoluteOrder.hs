{-# LANGUAGE OverloadedStrings #-}
module Order.AbsoluteOrder
  ( PerfectStructure(..)
  , AbsoluteHarmony
  , CompleteLogic
  , establishOrder
  ) where

import Data.Text (Text)

-- | Absolute order type
data PerfectStructure = PerfectStructure
  { psId :: Text
  , psIsPerfect :: Bool
  , psIsAbsolute :: Bool
  } deriving (Eq, Show)

-- | Absolute harmony type
type AbsoluteHarmony = PerfectStructure

-- | Complete logic type
type CompleteLogic = PerfectStructure

-- | Establish absolute order
establishOrder :: AbsoluteHarmony
establishOrder = PerfectStructure "order-001" True True