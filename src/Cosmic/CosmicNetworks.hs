{-# LANGUAGE OverloadedStrings #-}
module Cosmic.CosmicNetworks
  ( CosmicNode(..)
  , WormholeRoute(..)
  , CosmicNetwork
  , createNetwork
  , routeThroughWormhole
  ) where

import Data.Text (Text)
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as M
import Data.Aeson (Value)

-- | Cosmic node representation
data CosmicNode = CosmicNode
  { cnId :: Text
  , cnPosition :: (Double, Double, Double)
  , cnCapacity :: Int
  } deriving (Eq, Show)

-- | Wormhole route
data WormholeRoute = WormholeRoute
  { wrSource :: Text
  , wrTarget :: Text
  , wrStability :: Double
  } deriving (Eq, Show)

-- | Cosmic network type
type CosmicNetwork = Map Text CosmicNode

-- | Create a cosmic network
createNetwork :: [CosmicNode] -> CosmicNetwork
createNetwork nodes = M.fromList [(cnId n, n) | n <- nodes]

-- | Route data through wormhole
routeThroughWormhole :: WormholeRoute -> Value -> Value
routeThroughWormhole _ dataVal = dataVal