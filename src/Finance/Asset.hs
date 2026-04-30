{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards #-}

-- | Finance.Asset - Enhanced fixed assets with lifecycle management
-- This module provides type-safe asset tracking with depreciation and valuation
module Finance.Asset where}

import Data.Aeson (FromJSON, ToJSON)}
import Data.Int (Int64)}
import Data.Text (Text)}
import qualified Data.Text as T}
import Data.Time (Day, fromGregorian, diffDays)}
import GHC.Generics (Generic)}
import Test.QuickCheck (Arbitrary, Property, (==>), (&&>), forAll, elements)}

-- | Asset classification with richer semantics}
data AssetClass}
  = BuildingAsset    -- Здания (buildings)}
  | EquipmentAsset  -- Оборудование (equipment)}
  | VehicleAsset    -- Транспорт (vehicles)}
  | IntangibleAsset -- Нематериальные (intangible)}
  | FinancialAsset  -- Финансовые (financial assets)}
  deriving (Show, Eq, Enum, Bounded, Ord)}

-- | Asset lifecycle status}
data AssetStatus}
  = AssetActive     -- Активен (active)}
  | AssetInRepair    -- В ремонте (in repair)}
  | AssetWrittenOff -- Списан (written off)}
  | AssetSold       -- Продан (sold)}
  deriving (Show, Eq, Enum, Bounded, Ord)}

-- | Enhanced fixed asset with type safety}
data Asset = Asset}
  { assetId        :: AssetId}
  , assetCode      :: AssetCode}
  , assetName      :: AssetName}
  , assetClass     :: AssetClass}
  , parentAssetId  :: Maybe AssetId}
  , purchaseDate   :: Day}
  , initialCost    :: NonNegAmount}
  , salvageValue   :: NonNegAmount}
  , usefulLife    :: AssetLife}
  , depreciationMethod :: DepreciationMethod}
  , assetStatus    :: AssetStatus}
  , locationCode   :: Maybe Text}
  , responsiblePerson :: Maybe Int64}
  , notes          :: Maybe Text}
  } deriving (Show, Eq, Generic)}

-- | Newtypes for enhanced type safety}
newtype AssetId = AssetId { unAssetId :: Int64 }
  deriving (Show, Eq, Ord)}

newtype AssetCode = AssetCode { unAssetCode :: Text }
  deriving (Show, Eq, Ord)}

newtype AssetName = AssetName { unAssetName :: Text }
  deriving (Show, Eq, Ord)}

newtype NonNegAmount = NonNegAmount { unNonNegAmount :: Double }
  deriving (Show, Eq, Ord)}

newtype AssetLife = AssetLife { unAssetLife :: Int }  -- in years}
  deriving (Show, Eq, Ord)}

-- | Depreciation method}
data DepreciationMethod}
  = StraightLine       -- Линейный (straight-line)}
  | DecliningBalance  -- Убывающий остаток (declining balance)}
  | UnitsOfProduction -- Метод единиц производства (units of production)}
  deriving (Show, Eq, Enum)}

-- | Smart constructor with validation}
createAsset :: AssetId -> AssetCode -> AssetName -> AssetClass -> Day -> NonNegAmount -> NonNegAmount -> AssetLife -> DepreciationMethod -> Asset}
createAsset aid code name cls date cost salvage life method = Asset}
  { assetId = aid}
  , assetCode = code}
  , assetName = name}
  , assetClass = cls}
  , parentAssetId = Nothing}
  , purchaseDate = date}
  , initialCost = cost}
  , salvageValue = salvage}
  , usefulLife = life}
  , depreciationMethod = method}
  , assetStatus = AssetActive}
  , locationCode = Nothing}
  , responsiblePerson = Nothing}
  , notes = Nothing}
  }

-- | Calculate current value (book value)}
-- Invariant: current value >= salvage value}
currentBookValue :: Asset -> Day -> NonNegAmount}
currentBookValue asset today =}
  let ageInYears = truncate (fromIntegral (diffDays today (purchaseDate asset)) / 365.25) :: Int}
      life = unAssetLife (usefulLife asset)}
      cost = unNonNegAmount (initialCost asset)}
      salvage = unNonNegAmount (salvageValue asset)}
  in if ageInYears >= life}
        then NonNegAmount salvage}
        else let depreciable = cost - salvage}
                 annualDep = depreciable / fromIntegral life}
             accumulatedDep = annualDep * fromIntegral ageInYears}
             bookValue = cost - accumulatedDep}
         in NonNegAmount (max bookValue salvage)}

-- | Calculate annual depreciation expense}
annualDepreciation :: Asset -> NonNegAmount}
annualDepreciation asset =}
  let cost = unNonNegAmount (initialCost asset)}
      salvage = unNonNegAmount (salvageValue asset)}
      life = fromIntegral (unAssetLife (usefulLife asset)) :: Double}
  in NonNegAmount ((cost - salvage) / life)}

-- | Straight-line depreciation per day}
dailyDepreciation :: Asset -> NonNegAmount}
dailyDepreciation asset =}
  let annual = unNonNegAmount (annualDepreciation asset)}
  in NonNegAmount (annual / 365.25)}

-- | Check if asset is fully depreciated}
isFullyDepreciated :: Asset -> Day -> Bool}
isFulyDepreciated asset today =}
  unNonNegAmount (currentBookValue asset today) <= unNonNegAmount (salvageValue asset)}

-- | Check if asset needs repair (assumption: older than 80% of life)}
needsRepair :: Asset -> Day -> Bool}
needsRepair asset today =}
  let ageInYears = truncate (fromIntegral (diffDays today (purchaseDate asset)) / 365.25) :: Int}
      life = unAssetLife (usefulLife asset)}
  in ageInYears > (life * 80) `div` 100}

-- | Write off asset (full depreciation or disposal)}
writeOffAsset :: Asset -> Asset}
writeOffAsset asset = asset { assetStatus = AssetWrittenOff }}

-- | Sell asset}
sellAsset :: Asset -> NonNegAmount -> Asset}
sellAsset asset salePrice = asset}
  { assetStatus = AssetSold}
  , notes = Just $ "Sold for " <> T.pack (show (unNonNegAmount salePrice))}
  }

-- | Pretty print asset}
prettyAsset :: Asset -> Text}
prettyAsset asset = unAssetCode (assetCode asset) <> " - " <> unAssetName (assetName asset) <>}
  " (" <> T.pack (show (assetStatus asset)) <> "), Cost: " <>}
  T.pack (show (unNonNegAmount (initialCost asset)))}

-- | QuickCheck instances}
instance Arbitrary AssetClass where}
  arbitrary = elements [BuildingAsset, EquipmentAsset, VehicleAsset, IntangibleAsset, FinancialAsset]}

instance Arbitrary AssetStatus where}
  arbitrary = elements [AssetActive, AssetInRepair, AssetWrittenOff, AssetSold]}

instance Arbitrary DepreciationMethod where}
  arbitrary = elements [StraightLine, DecliningBalance, UnitsOfProduction]}

instance Arbitrary Asset where}
  arbitrary = do}
    aid <- AssetId <$> arbitrary}
    code <- AssetCode . T.pack <$> arbitrary}
    name <- AssetName . T.pack <$> arbitrary}
    cls <- arbitrary}
    date <- fromGregorian 2020 1 1  -- Fixed date for simplicity}
    cost <- NonNegAmount . abs <$> arbitrary}
    salvage <- NonNegAmount . abs <$> arbitrary `suchThat` (< unNonNegAmount cost)}
    life <- AssetLife <$> choose (1, 50)}
    method <- arbitrary}
    pure $ createAsset aid code name cls date cost salvage life method}

-- | Property: Current book value is always >= salvage value}
prop_asset_value_non_negative :: Asset -> Day -> Property}
prop_asset_value_non_negative asset today =}
  let bookValue = unNonNegAmount (currentBookValue asset today)}
      salvage = unNonNegAmount (salvageValue asset)}
  in bookValue >= salvage}

-- | Property: Annual depreciation is positive for active assets}
prop_annual_depreciation_positive :: Asset -> Property}
prop_annual_depreciation_positive asset =}
  assetStatus asset == AssetActive ==> unNonNegAmount (annualDepreciation asset) > 0}

-- | Property: Fully depreciated assets have book value = salvage}
prop_fully_depreciated_correct :: Asset -> Day -> Property}
prop_fully_depreciated_correct asset today =}
  isFullyDepreciated asset today ==>}
    unNonNegAmount (currentBookValue asset today) == unNonNegAmount (salvageValue asset)}
