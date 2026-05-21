{-# LANGUAGE OverloadedStrings #-}
module Return.EternalReturn
  ( EternalCycle(..)
  , InfiniteRenewal
  , CyclicalExistence
  , initiateCycle
  ) where

import Data.Text (Text)

-- | Eternal cycle type
data EternalCycle = EternalCycle
  { ecId :: Text
  , ecIsInfinite :: Bool
  , ecIsCyclical :: Bool
  } deriving (Eq, Show)

-- | Infinite renewal type
type InfiniteRenewal = EternalCycle

-- | Cyclical existence type
type CyclicalExistence = ()

-- | Initiate eternal cycle
initiateCycle :: InfiniteRenewal
initiateCycle = EternalCycle "cycle-001" True True