{-# LANGUAGE OverloadedStrings #-}
module Pulse.EternalPulse
  ( InfiniteHeartbeat(..)
  , PerpetualThrob
  , TimelessPulse
  , pulseEternal
  ) where

import Data.Text (Text)

-- | Eternal pulse type
data InfiniteHeartbeat = InfiniteHeartbeat
  { ihId :: Text
  , ihIsInfinite :: Bool
  , ihIsPerpetual :: Bool
  } deriving (Eq, Show)

-- | Perpetual throb type
type PerpetualThrob = InfiniteHeartbeat

-- | Timeless pulse type
type TimelessPulse = InfiniteHeartbeat

-- | Pulse eternal
pulseEternal :: InfiniteHeartbeat
pulseEternal = InfiniteHeartbeat "pulse-001" True True