-- | Location types - Warehouses and stores
module Core.Inventory.Types.Location where

import Data.Int (Int64)
import Data.Text (Text)

-- | Location - Warehouse or store
data Location = Location
  { locId :: Int64,
    locCode :: Text,
    locName :: Text,
    locType :: LocationType,
    locParentId :: Maybe Int64,
    locAddress :: Text,
    locFlags :: Int
  }
  deriving (Show, Eq)

-- | Location type
data LocationType
  = LT_Warehouse -- Склад
  | LT_Store -- Магазин
  | LT_Office -- Офис
  | LT_Transit -- Транзит
  deriving (Show, Eq, Enum)

-- | Location flags
data LocationFlags = LocationFlags
  { lfActive :: Bool,
    lfPrimary :: Bool,
    lfAcceptReturns :: Bool
  }
  deriving (Show, Eq)
