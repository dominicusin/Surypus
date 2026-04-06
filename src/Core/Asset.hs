{-# LANGUAGE DeriveGeneric #-}

-- | Asset module - Fixed assets
module Core.Asset
  ( Asset (..),
    AssetStatus (..),
    AssetWriteOff (..),
    calcCurrentValue,
    prop_assetValueNonNeg,
  )
where

import Data.Aeson (FromJSON, ToJSON)
import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import Data.Time (Day, fromGregorian)
import GHC.Generics (Generic)
import Test.QuickCheck

{-@ type NonNeg = {v:Double | v >= 0} @-}

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

{-@ calcCurrentValue :: Asset -> NonNeg @-}
calcCurrentValue :: Asset -> Double
calcCurrentValue a = astInitCost a - astDepreciation a

-- ============================================================================
-- QUICKCHECK PROPERTIES
-- ============================================================================

instance Arbitrary Asset where
  arbitrary = do
    initCost <- suchThat arbitrary (> 0)
    depreciation <- choose (0, initCost)
    status <- elements [ASActive, ASInRepair, ASWrittenOff]
    pure $ Asset 0 (T.pack "") (T.pack "") 0 initCost depreciation (fromGregorian 2024 1 1) status

prop_assetValueNonNeg :: Asset -> Property
prop_assetValueNonNeg a =
  let initCost = astInitCost a
      depreciation = astDepreciation a
   in initCost >= 0 && depreciation >= 0 && depreciation <= initCost ==> calcCurrentValue a >= 0
