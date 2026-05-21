{-# LANGUAGE OverloadedStrings #-}
module Creation.InfiniteCreation
  ( InfiniteCreator(..)
  , UnboundedCreativity
  , GenerativePower
  , unleashCreation
  ) where

import Data.Text (Text)

-- | Infinite creator type
data InfiniteCreator = InfiniteCreator
  { icId :: Text
  , icIsUnbounded :: Bool
  , icIsCreative :: Bool
  } deriving (Eq, Show)

-- | Unbounded creativity type
type UnboundedCreativity = InfiniteCreator

-- | Generative power type
type GenerativePower = InfiniteCreator

-- | Unleash infinite creation
unleashCreation :: UnboundedCreativity
unleashCreation = InfiniteCreator "creator-001" True True