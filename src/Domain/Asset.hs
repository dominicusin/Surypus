{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards #-}

{-@ LIQUID "--reflection" @-}

module Domain.Asset
  ( Asset (..),
    AssetInput (..),
    AssetStatus (..),
    AssetEvent (..),
    AssetEventType (..),
    AssetDepreciation (..),
    assetResidualValue,
    validateAssetInput,
    mkAssetEvent,
    mkAssetDepreciation,
  )
where

import Core.Asset (AssetStatus (..))
import Core.Refined (clampNonNeg)
import Data.Aeson (FromJSON, ToJSON)
import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import Data.Time (Day)
import GHC.Generics (Generic)

{-@ type NonNegDouble = {v:Double | v >= 0} @-}

{-@ data Asset = Asset
  { astId        :: Int64
  , astInvNo     :: Text
  , astName      :: Text
  , astGroupId   :: Maybe Int64
  , astLocation  :: Maybe Int64
  , astOwner     :: Maybe Int64
  , astStatus    :: AssetStatus
  , astCost      :: NonNegDouble
  , astDepreciation :: NonNegDouble
  , astSalvage   :: NonNegDouble
  , astUsefulLife :: {v:Int | v >= 0}
  , astPurchaseDate :: Maybe Day
  , astCommissioning :: Maybe Day
  } @-}
data Asset = Asset
  { astId :: Int64,
    astInvNo :: Text,
    astName :: Text,
    astGroupId :: Maybe Int64,
    astLocation :: Maybe Int64,
    astOwner :: Maybe Int64,
    astStatus :: AssetStatus,
    astCost :: Double,
    astDepreciation :: Double,
    astSalvage :: Double,
    astUsefulLife :: Int,
    astPurchaseDate :: Maybe Day,
    astCommissioning :: Maybe Day
  }
  deriving (Eq, Show, Generic)

instance ToJSON Asset

instance FromJSON Asset

{-@ data AssetInput = AssetInput
  { aiInvNo     :: Text
  , aiName      :: Text
  , aiType      :: Int
  , aiGroupId   :: Maybe Int64
  , aiLocation  :: Maybe Int64
  , aiOwner     :: Maybe Int64
  , aiCost      :: NonNegDouble
  , aiSalvage   :: NonNegDouble
  , aiUsefulLife :: {v:Int | v >= 1}
  , aiPurchaseDate :: Maybe Day
  , aiCommissioning :: Maybe Day
  } @-}
data AssetInput = AssetInput
  { aiInvNo :: Text,
    aiName :: Text,
    aiType :: Int,
    aiGroupId :: Maybe Int64,
    aiLocation :: Maybe Int64,
    aiOwner :: Maybe Int64,
    aiCost :: Double,
    aiSalvage :: Double,
    aiUsefulLife :: Int,
    aiPurchaseDate :: Maybe Day,
    aiCommissioning :: Maybe Day
  }
  deriving (Eq, Show, Generic)

instance ToJSON AssetInput

instance FromJSON AssetInput

{-@ data AssetDepreciation = AssetDepreciation
  { adAssetId :: Int64
  , adPeriod  :: Day
  , adAmount  :: NonNegDouble
  , adAccum   :: NonNegDouble
  } @-}
data AssetDepreciation = AssetDepreciation
  { adId :: Int64,
    adAssetId :: Int64,
    adPeriod :: Day,
    adAmount :: Double,
    adAccum :: Double,
    adMethod :: Int
  }
  deriving (Eq, Show, Generic)

instance ToJSON AssetDepreciation

instance FromJSON AssetDepreciation

{-@ data AssetEvent = AssetEvent
  { aeAssetId :: Int64
  , aeType    :: AssetEventType
  , aeDate    :: Day
  , aeAmount  :: NonNegDouble
  , aeDesc    :: Text
  } @-}
data AssetEvent = AssetEvent
  { aeId :: Int64,
    aeAssetId :: Int64,
    aeType :: AssetEventType,
    aeDate :: Day,
    aeAmount :: Double,
    aeDesc :: Text
  }
  deriving (Eq, Show, Generic)

instance ToJSON AssetEvent

instance FromJSON AssetEvent

data AssetEventType
  = AEPurchase
  | AECommission
  | AETransfer
  | AERepair
  | AEDepreciate
  | AESell
  | AEWriteOff
  deriving (Eq, Show, Enum, Generic)

instance ToJSON AssetEventType

instance FromJSON AssetEventType

assetResidualValue :: Asset -> Double
assetResidualValue Asset {..} = clampNonNeg (astCost - astDepreciation - astSalvage)

validateAssetInput :: AssetInput -> Either Text AssetInput
validateAssetInput input@AssetInput {..}
  | T.strip aiInvNo == "" = Left "inventory number is required"
  | T.strip aiName == "" = Left "asset name is required"
  | aiCost < 0 = Left "cost cannot be negative"
  | aiSalvage < 0 = Left "salvage cannot be negative"
  | aiSalvage > aiCost = Left "salvage cannot exceed cost"
  | aiUsefulLife <= 0 = Left "useful life must be positive"
  | otherwise = Right input

mkAssetEvent :: Int64 -> AssetEventType -> Day -> Double -> Text -> AssetEvent
mkAssetEvent assetId etype dt amount desc = AssetEvent 0 assetId etype dt (max 0 amount) desc -- hlint: ignore

mkAssetDepreciation :: Int64 -> Day -> Double -> Double -> Int -> AssetDepreciation
mkAssetDepreciation = AssetDepreciation 0
