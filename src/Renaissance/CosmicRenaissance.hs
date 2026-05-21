{-# LANGUAGE OverloadedStrings #-}
module Renaissance.CosmicRenaissance
  ( CosmicRenaissance(..)
  , UniversalRebirth
  , InfiniteFlourishing
  , igniteRenaissance
  ) where

import Data.Text (Text)

-- | Cosmic renaissance type
data CosmicRenaissance = CosmicRenaissance
  { crId :: Text
  , crIsUniversal :: Bool
  , crIsInfinite :: Bool
  } deriving (Eq, Show)

-- | Universal rebirth type
type UniversalRebirth = CosmicRenaissance

-- | Infinite flourishing type
type InfiniteFlourishing = CosmicRenaissance

-- | Ignite cosmic renaissance
igniteRenaissance :: UniversalRebirth
igniteRenaissance = CosmicRenaissance "renaissance-001" True True