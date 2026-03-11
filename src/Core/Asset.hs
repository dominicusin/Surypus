-- | Asset module - Fixed assets
module Core.Asset where

import           Data.Int  (Int64)
import           Data.Text (Text)
import           Data.Time (Day)

-- | Asset - Fixed asset
data Asset = Asset
  { astId           :: Int64
  , astCode         :: Text
  , astName         :: Text
  , astGroupId      :: Int64
  , astInitCost     :: Double
  , astDepreciation:: Double
  , astDate         :: Day
  , astStatus       :: AssetStatus
  } deriving (Show, Eq)

data AssetStatus = AS_Active | AS_InRepair | AS_WrittenOff
  deriving (Show, Eq)

-- | AssetWriteOff - Asset write-off
data AssetWriteOff = AssetWriteOff
  { awId      :: Int64
  , awAssetId :: Int64
  , awDate    :: Day
  , awCost    :: Double
  , awReason  :: Text
  } deriving (Show, Eq)

-- | Calculate current value
calcCurrentValue :: Asset -> Double
calcCurrentValue a = astInitCost a - astDepreciation a
