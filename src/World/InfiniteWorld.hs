{-# LANGUAGE OverloadedStrings #-}
module World.InfiniteWorld
  ( InfiniteRealm(..)
  , BoundlessExistence
  , EndlessDomain
  , enterWorld
  ) where

import Data.Text (Text)

-- | Infinite realm type
data InfiniteRealm = InfiniteRealm
  { irId :: Text
  , irIsBoundless :: Bool
  , irIsEndless :: Bool
  } deriving (Eq, Show)

-- | Boundless existence type
type BoundlessExistence = InfiniteRealm

-- | Endless domain type
type EndlessDomain = InfiniteRealm

-- | Enter infinite world
enterWorld :: BoundlessExistence
enterWorld = InfiniteRealm "world-001" True True