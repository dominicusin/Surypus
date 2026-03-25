{-# LANGUAGE DeriveGeneric #-}

-- | Asset module - Fixed assets
module Core.Asset where

import Data.Aeson (FromJSON, ToJSON)
import Data.Int (Int64)
import Data.Text (Text)
import Data.Time (Day)
import GHC.Generics (Generic)

-- | Asset - Fixed asset
data Asset = Asset
  { astId :: Int64,
    astCode :: Text,
    astName :: Text,
    astGroupId :: Int64,
    astInitCost :: Double,
    astDepreciation :: Double,
    astDate :: Day,
    astStatus :: AssetStatus
  }
  deriving (Show, Eq)

data AssetStatus = ASActive | ASInRepair | ASWrittenOff
  deriving (Show, Eq, Generic)

instance ToJSON AssetStatus

instance FromJSON AssetStatus

-- | AssetWriteOff - Asset write-off
data AssetWriteOff = AssetWriteOff
  { awId :: Int64,
    awAssetId :: Int64,
    awDate :: Day,
    awCost :: Double,
    awReason :: Text
  }
  deriving (Show, Eq)

-- | Calculate current value
calcCurrentValue :: Asset -> Double
calcCurrentValue a = astInitCost a - astDepreciation a
