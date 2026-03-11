{-# LANGUAGE OverloadedStrings #-}

module DB.Asset
  ( listAssets
  , getAsset
  , createAsset
  , depreciateAsset
  , recordAssetEvent
  , listAssetEvents
  , listAssetDepreciations
  ) where

import Data.Int (Int64)
import Data.Text (Text)
import Data.Time (Day)
import Hasql.Pool (Pool, use)
import Hasql.Statement (Statement(..))
import qualified Hasql.Decoders as D
import qualified Hasql.Encoders as E
import qualified Hasql.Session as Session
import Domain.Asset

assetRow :: D.Row Asset
assetRow = Asset
  <$> D.column (D.nonNullable D.int8)
  <*> D.column (D.nonNullable D.text)
  <*> D.column (D.nonNullable D.text)
  <*> D.column (D.nullable D.int8)
  <*> D.column (D.nullable D.int8)
  <*> D.column (D.nullable D.int8)
  <*> (assetStatusFromInt <$> D.column (D.nonNullable D.int4))
  <*> D.column (D.nonNullable D.float8)
  <*> D.column (D.nonNullable D.float8)
  <*> D.column (D.nonNullable D.float8)
  <*> D.column (D.nonNullable D.int4)
  <*> D.column (D.nullable D.date)
  <*> D.column (D.nullable D.date)

assetStatusFromInt :: Int -> AssetStatus
assetStatusFromInt 0 = AS_Active
assetStatusFromInt 1 = AS_InRepair
assetStatusFromInt 2 = AS_WrittenOff
assetStatusFromInt _ = AS_Active

assetStatusToInt :: AssetStatus -> Int
assetStatusToInt AS_Active = 0
assetStatusToInt AS_InRepair = 1
assetStatusToInt AS_WrittenOff = 2

listAssets :: Pool -> IO [Asset]
listAssets pool = use pool $ Session.statement () stmt
  where
    stmt = Statement
      "SELECT id, inv_no, name, group_id, location_id, owner_id, status, cost, depreciation, salvage_value, useful_life, purchase_date, commissioning_date FROM asset"
      E.noParams
      (D.rowList assetRow)
      False

getAsset :: Pool -> Int64 -> IO (Maybe Asset)
getAsset pool astId = use pool $ Session.statement astId stmt
  where
    stmt = Statement
      "SELECT id, inv_no, name, group_id, location_id, owner_id, status, cost, depreciation, salvage_value, useful_life, purchase_date, commissioning_date FROM asset WHERE id = $1"
      (E.param (E.nonNullable E.int8))
      (D.rowMaybe assetRow)
      False

createAsset :: Pool -> AssetInput -> IO Asset
createAsset pool AssetInput{..} = use pool $ Session.statement params stmt
  where
    params = (aiInvNo, aiName, aiType, aiGroupId, aiLocation, aiOwner, aiCost, aiSalvage, aiUsefulLife, aiPurchaseDate, aiCommissioning)
    stmt = Statement
      "INSERT INTO asset (inv_no, name, atype, group_id, location_id, owner_id, cost, salvage_value, useful_life, purchase_date, commissioning_date) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11) RETURNING id, inv_no, name, group_id, location_id, owner_id, status, cost, depreciation, salvage_value, useful_life, purchase_date, commissioning_date"
      (  E.param (E.nonNullable E.text)
      <> E.param (E.nonNullable E.text)
      <> E.param (E.nonNullable E.int4)
      <> E.param (E.nullable E.int8)
      <> E.param (E.nullable E.int8)
      <> E.param (E.nullable E.int8)
      <> E.param (E.nonNullable E.float8)
      <> E.param (E.nonNullable E.float8)
      <> E.param (E.nonNullable E.int4)
      <> E.param (E.nullable E.date)
      <> E.param (E.nullable E.date)
      )
      (D.rowOne assetRow)
      False

depreciateAsset :: Pool -> Int64 -> Day -> IO Bool
depreciateAsset pool assetId period = do
  mb <- use pool $ Session.statement (assetId, period) stmt
  return (mb /= Nothing)
  where
    stmt = Statement
      "SELECT depreciate_asset_month($1, $2)"
      (  E.param (E.nonNullable E.int8)
      <> E.param (E.nonNullable E.date)
      )
      (D.singleRow $ D.column (D.nonNullable D.bool))
      False

recordAssetEvent :: Pool -> AssetEvent -> IO Int64
recordAssetEvent pool AssetEvent{..} = use pool $ Session.statement params stmt
  where
    params = (aeAssetId, assetEventTypeToInt aeType, aeDate, aeAmount, aeDesc)
    stmt = Statement
      "INSERT INTO asset_event (asset_id, etype, dt, amount, description) VALUES ($1,$2,$3,$4,$5) RETURNING id"
      (  E.param (E.nonNullable E.int8)
      <> E.param (E.nonNullable E.int4)
      <> E.param (E.nonNullable E.date)
      <> E.param (E.nonNullable E.float8)
      <> E.param (E.nonNullable E.text)
      )
      (D.singleRow $ D.column (D.nonNullable D.int8))
      False

listAssetEvents :: Pool -> Int64 -> IO [AssetEvent]
listAssetEvents pool assetId = use pool $ Session.statement assetId stmt
  where
    stmt = Statement
      "SELECT id, asset_id, etype, dt, amount, description FROM asset_event WHERE asset_id = $1 ORDER BY dt DESC"
      (E.param (E.nonNullable E.int8))
      (D.rowList assetEventRow)
      False

assetEventRow :: D.Row AssetEvent
assetEventRow = AssetEvent
  <$> D.column (D.nonNullable D.int8)
  <*> D.column (D.nonNullable D.int8)
  <*> (assetEventTypeFromInt <$> D.column (D.nonNullable D.int4))
  <*> D.column (D.nonNullable D.date)
  <*> D.column (D.nonNullable D.float8)
  <*> D.column (D.nonNullable D.text)

assetEventTypeFromInt :: Int -> AssetEventType
assetEventTypeFromInt 0 = AE_Purchase
assetEventTypeFromInt 1 = AE_Commission
assetEventTypeFromInt 2 = AE_Transfer
assetEventTypeFromInt 3 = AE_Repair
assetEventTypeFromInt 4 = AE_Depreciate
assetEventTypeFromInt 5 = AE_Sell
assetEventTypeFromInt 6 = AE_WriteOff
assetEventTypeFromInt _ = AE_Purchase

assetEventTypeToInt :: AssetEventType -> Int
assetEventTypeToInt AE_Purchase = 0
assetEventTypeToInt AE_Commission = 1
assetEventTypeToInt AE_Transfer = 2
assetEventTypeToInt AE_Repair = 3
assetEventTypeToInt AE_Depreciate = 4
assetEventTypeToInt AE_Sell = 5
assetEventTypeToInt AE_WriteOff = 6

listAssetDepreciations :: Pool -> Int64 -> IO [AssetDepreciation]
listAssetDepreciations pool assetId = use pool $ Session.statement assetId stmt
  where
    stmt = Statement
      "SELECT id, asset_id, period, amount, accumulated, method FROM asset_depreciation WHERE asset_id = $1 ORDER BY period DESC"
      (E.param (E.nonNullable E.int8))
      (D.rowList assetDepRow)
      False

assetDepRow :: D.Row AssetDepreciation
assetDepRow = AssetDepreciation
  <$> D.column (D.nonNullable D.int8)
  <*> D.column (D.nonNullable D.int8)
  <*> D.column (D.nonNullable D.date)
  <*> D.column (D.nonNullable D.float8)
  <*> D.column (D.nonNullable D.float8)
  <*> D.column (D.nonNullable D.int4)
