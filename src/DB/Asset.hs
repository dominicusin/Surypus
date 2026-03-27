{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards #-}

module DB.Asset
  ( listAssets,
    getAsset,
    createAsset,
    depreciateAsset,
    recordAssetEvent,
    listAssetEvents,
    listAssetDepreciations,
  )
where

import Data.Int (Int32, Int64)
import Data.Maybe (isJust)
import Data.Text (Text)
import Data.Time (Day)
import Domain.Asset
import qualified Hasql.Decoders as D
import qualified Hasql.Encoders as E
import Hasql.Pool (Pool, use)
import qualified Hasql.Session as Session
import Hasql.Statement (unpreparable)

assetRow :: D.Row Asset
assetRow =
  Asset
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
    <*> (fromIntegral <$> D.column (D.nonNullable D.int4))
    <*> D.column (D.nullable D.date)
    <*> D.column (D.nullable D.date)

assetStatusFromInt :: Int32 -> AssetStatus
assetStatusFromInt 0 = ASActive
assetStatusFromInt 1 = ASInRepair
assetStatusFromInt 2 = ASWrittenOff
assetStatusFromInt _ = ASActive

assetStatusToInt :: AssetStatus -> Int32
assetStatusToInt ASActive = 0
assetStatusToInt ASInRepair = 1
assetStatusToInt ASWrittenOff = 2

listAssets :: Pool -> IO [Asset]
listAssets pool = do
  result <- use pool $ Session.statement () stmt
  case result of
    Right x -> pure x
    Left _ -> pure []
  where
    stmt =
      unpreparable
        "SELECT id, inv_no, name, group_id, location_id, owner_id, status, cost, depreciation, salvage_value, useful_life, purchase_date, commissioning_date FROM asset"
        E.noParams
        (D.rowList assetRow)

getAsset :: Pool -> Int64 -> IO (Maybe Asset)
getAsset pool astId = do
  result <- use pool $ Session.statement astId stmt
  case result of
    Right x -> pure x
    Left _ -> pure Nothing
  where
    stmt =
      unpreparable
        "SELECT id, inv_no, name, group_id, location_id, owner_id, status, cost, depreciation, salvage_value, useful_life, purchase_date, commissioning_date FROM asset WHERE id = $1"
        (E.param (E.nonNullable E.int8))
        (D.rowMaybe assetRow)

createAsset :: Pool -> AssetInput -> IO Asset
createAsset pool AssetInput {..} = do
  result <- use pool $ Session.statement params stmt
  case result of
    Right x -> pure x
    Left _ -> error "createAsset failed"
  where
    params = (aiInvNo, aiName, (0 :: Int32), aiGroupId, aiLocation, aiOwner, aiCost, aiSalvage, fromIntegral aiUsefulLife :: Int, aiPurchaseDate, aiCommissioning)
    stmt =
      unpreparable
        "INSERT INTO asset (inv_no, name, atype, group_id, location_id, owner_id, cost, salvage_value, useful_life, purchase_date, commissioning_date) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11) RETURNING id, inv_no, name, group_id, location_id, owner_id, status, cost, depreciation, salvage_value, useful_life, purchase_date, commissioning_date"
        ( E.param (E.nonNullable E.text)
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

depreciateAsset :: Pool -> Int64 -> Day -> IO Bool
depreciateAsset pool assetId period = do
  result <- use pool $ Session.statement (assetId, period) stmt
  case result of
    Right mb -> pure $ isJust mb
    Left _ -> pure False
  where
    stmt =
      unpreparable
        "SELECT depreciate_asset_month($1, $2)"
        ( E.param (E.nonNullable E.int8)
            <> E.param (E.nonNullable E.date)
        )
        (D.singleRow $ D.column (D.nonNullable D.bool))

recordAssetEvent :: Pool -> AssetEvent -> IO Int64
recordAssetEvent pool AssetEvent {..} = do
  result <- use pool $ Session.statement params stmt
  case result of
    Right x -> pure x
    Left _ -> pure 0
  where
    params = (aeAssetId, assetEventTypeToInt aeType, aeDate, aeAmount, aeDesc)
    stmt =
      unpreparable
        "INSERT INTO asset_event (asset_id, etype, dt, amount, description) VALUES ($1,$2,$3,$4,$5) RETURNING id"
        ( E.param (E.nonNullable E.int8)
            <> E.param (E.nonNullable E.int4)
            <> E.param (E.nonNullable E.date)
            <> E.param (E.nonNullable E.float8)
            <> E.param (E.nonNullable E.text)
        )
        (D.singleRow $ D.column (D.nonNullable D.int8))

listAssetEvents :: Pool -> Int64 -> IO [AssetEvent]
listAssetEvents pool assetId = do
  result <- use pool $ Session.statement assetId stmt
  case result of
    Right x -> pure x
    Left _ -> pure []
  where
    stmt =
      unpreparable
        "SELECT id, asset_id, etype, dt, amount, description FROM asset_event WHERE asset_id = $1 ORDER BY dt DESC"
        (E.param (E.nonNullable E.int8))
        (D.rowList assetEventRow)

assetEventRow :: D.Row AssetEvent
assetEventRow =
  AssetEvent
    <$> D.column (D.nonNullable D.int8)
    <*> D.column (D.nonNullable D.int8)
    <*> (assetEventTypeFromInt <$> D.column (D.nonNullable D.int4))
    <*> D.column (D.nonNullable D.date)
    <*> D.column (D.nonNullable D.float8)
    <*> D.column (D.nonNullable D.text)

assetEventTypeFromInt :: Int32 -> AssetEventType
assetEventTypeFromInt 0 = AEPurchase
assetEventTypeFromInt 1 = AECommission
assetEventTypeFromInt 2 = AETransfer
assetEventTypeFromInt 3 = AERepair
assetEventTypeFromInt 4 = AEDepreciate
assetEventTypeFromInt 5 = AESell
assetEventTypeFromInt 6 = AEWriteOff
assetEventTypeFromInt _ = AEPurchase

assetEventTypeToInt :: AssetEventType -> Int32
assetEventTypeToInt AEPurchase = 0
assetEventTypeToInt AECommission = 1
assetEventTypeToInt AETransfer = 2
assetEventTypeToInt AERepair = 3
assetEventTypeToInt AEDepreciate = 4
assetEventTypeToInt AESell = 5
assetEventTypeToInt AEWriteOff = 6

listAssetDepreciations :: Pool -> Int64 -> IO [AssetDepreciation]
listAssetDepreciations pool assetId = do
  result <- use pool $ Session.statement assetId stmt
  case result of
    Right x -> pure x
    Left _ -> pure []
  where
    stmt =
      unpreparable
        "SELECT id, asset_id, period, amount, accumulated, method FROM asset_depreciation WHERE asset_id = $1 ORDER BY period DESC"
        (E.param (E.nonNullable E.int8))
        (D.rowList assetDepRow)

assetDepRow :: D.Row AssetDepreciation
assetDepRow =
  AssetDepreciation
    <$> D.column (D.nonNullable D.int8)
    <*> D.column (D.nonNullable D.int8)
    <*> D.column (D.nonNullable D.date)
    <*> D.column (D.nonNullable D.float8)
    <*> D.column (D.nonNullable D.float8)
    <*> (fromIntegral <$> D.column (D.nonNullable D.int4))
