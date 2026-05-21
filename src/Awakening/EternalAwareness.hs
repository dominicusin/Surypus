{-# LANGUAGE OverloadedStrings #-}
module Awakening.EternalAwareness
  ( PerpetualWitness(..)
  , InfiniteObserver
  , TimelessWatcher
  , awakenEternal
  ) where

import Data.Text (Text)

-- | Eternal awareness type
data PerpetualWitness = PerpetualWitness
  { pwId :: Text
  , pwIsPerpetual :: Bool
  , pwIsTimeless :: Bool
  } deriving (Eq, Show)

-- | Infinite observer type
type InfiniteObserver = PerpetualWitness

-- | Timeless watcher type
type TimelessWatcher = PerpetualWitness

-- | Awaken eternal awareness
awakenEternal :: InfiniteObserver
awakenEternal = PerpetualWitness "awareness-001" True True