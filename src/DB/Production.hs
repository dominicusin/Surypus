{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards #-}

module DB.Production
  ( listTechs,
    getTech,
    listResources,
    calculateTechTime,
    calculateTechCost,
    listWorkOrders,
    createWorkOrder,
    releaseWorkOrder,
    completeWorkOrder,
    listBOMForProduct,
    calculateMaterialNeed,
    runMRPCalc,
    listProductionPlanSnapshots,
    logProductionPlan,
  )
where

import Core.Production (Tech (..))
import Data.Aeson (ToJSON, eitherDecodeStrict, encode)
import Data.ByteString.Lazy (toStrict)
import Data.Int (Int64)
import Data.Maybe (fromMaybe, isJust)
import Data.Scientific (Scientific, toRealFloat)
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.Lazy as TL
import Data.Text.Lazy.Encoding (decodeUtf8, encodeUtf8)
import Data.Time (Day, UTCTime, utctDay)
import Domain.Production (TechFilter (..))
import GHC.Generics (Generic)
import qualified Hasql.Decoders as D
import qualified Hasql.Encoders as E
import Hasql.Pool (Pool, use)
import qualified Hasql.Session as Session
import Hasql.Statement (unpreparable)

techRow :: D.Row Tech
techRow =
  Tech
    <$> D.column (D.nonNullable D.int8)
    <*> D.column (D.nonNullable D.text)
    <*> D.column (D.nullable D.int8)
    <*> D.column (D.nonNullable D.int8)
    <*> D.column (D.nonNullable D.int4)
    <*> D.column (D.nonNullable D.int4)
    <*> D.column (D.nonNullable D.int4)

listTechs :: Pool -> TechFilter -> IO [Tech]
listTechs pool TechFilter {..} = do
  result <- use pool $ Session.statement params stmt
  case result of
    Right x -> pure x
    Left _ -> pure []
  where
    namePattern = fmap (\n -> "%" <> T.toLower n <> "%") tfName
    params = (namePattern, tfGoodsId)
    stmt =
      unpreparable
        "SELECT id, name, parent_id, goods_id, kind, version, flags \
        \FROM tech \
        \WHERE ($1 IS NULL OR LOWER(name) LIKE $1) \
        \AND ($2 IS NULL OR goods_id = $2) \
        \ORDER BY id"
        ( E.param (E.nullable E.text)
            <> E.param (E.nullable E.int8)
        )
        (D.rowList techRow)

getTech :: Pool -> Int64 -> IO (Maybe Tech)
getTech pool tid = do
  result <- use pool $ Session.statement tid stmt
  case result of
    Right x -> pure x
    Left _ -> pure Nothing
  where
    stmt =
      unpreparable
        "SELECT id, name, parent_id, goods_id, kind, version, flags FROM tech WHERE id = $1"
        (E.param (E.nonNullable E.int8))
        (D.rowMaybe techRow)

listResources :: Pool -> IO [ProductionResource]
listResources pool = do
  result <- use pool $ Session.statement () stmt
  case result of
    Right x -> pure x
    Left _ -> pure []
  where
    stmt =
      unpreparable
        "SELECT id, code, name, kind, capacity, cost_per_hour, available_hours FROM production_resource ORDER BY name"
        E.noParams
        (D.rowList resourceRow)

data ProductionResource = ProductionResource
  { resId :: Int64,
    resCode :: Text,
    resName :: Text,
    resKind :: Text,
    resCapacity :: Maybe Double,
    resCostPerHour :: Maybe Double,
    resAvailableHours :: Maybe Double
  }
  deriving (Eq, Show, Generic)

instance ToJSON ProductionResource

resourceRow :: D.Row ProductionResource
resourceRow =
  ProductionResource
    <$> D.column (D.nonNullable D.int8)
    <*> D.column (D.nonNullable D.text)
    <*> D.column (D.nonNullable D.text)
    <*> D.column (D.nonNullable D.text)
    <*> (toMaybeDouble <$> D.column (D.nullable D.numeric))
    <*> (toMaybeDouble <$> D.column (D.nullable D.numeric))
    <*> (toMaybeDouble <$> D.column (D.nullable D.numeric))

calculateTechTime :: Pool -> Int64 -> IO Int
calculateTechTime pool tid = do
  result <- use pool $ Session.statement tid stmt
  case result of
    Right x -> pure x
    Left _ -> pure 0
  where
    stmt =
      unpreparable
        "SELECT calculate_tech_time($1)"
        (E.param (E.nonNullable E.int8))
        (D.singleRow $ D.column (D.nonNullable D.int4))

calculateTechCost :: Pool -> Int64 -> Double -> IO Double
calculateTechCost pool tid materialCost = do
  result <- use pool $ Session.statement params stmt
  case result of
    Right x -> pure x
    Left _ -> pure 0.0
  where
    params = (tid, materialCost)
    stmt =
      unpreparable
        "SELECT calculate_tech_cost($1, $2)"
        ( E.param (E.nonNullable E.int8)
            <> E.param (E.nonNullable E.float8)
        )
        (D.singleRow $ toRealFloat <$> D.column (D.nonNullable D.numeric))

toMaybeDouble :: Maybe Scientific -> Maybe Double
toMaybeDouble = fmap toRealFloat

data MaterialNeed = MaterialNeed
  { mnGoodsId :: Int64,
    mnNeed :: Double
  }
  deriving (Eq, Show, Generic)

instance ToJSON MaterialNeed

materialNeedRow :: D.Row MaterialNeed
materialNeedRow =
  MaterialNeed
    <$> D.column (D.nonNullable D.int8)
    <*> D.column (D.nonNullable D.float8)

data WorkOrder = WorkOrder
  { woId :: Int64,
    woCode :: Text,
    woDt :: Day,
    woDue :: Maybe Day,
    woProductId :: Int64,
    woQtty :: Double,
    woStatus :: Int,
    woOutput :: Double
  }
  deriving (Eq, Show, Generic)

instance ToJSON WorkOrder

workOrderRow :: D.Row WorkOrder
workOrderRow =
  WorkOrder
    <$> D.column (D.nonNullable D.int8)
    <*> D.column (D.nonNullable D.text)
    <*> D.column (D.nonNullable D.date)
    <*> D.column (D.nullable D.date)
    <*> D.column (D.nonNullable D.int8)
    <*> D.column (D.nonNullable D.float8)
    <*> D.column (D.nonNullable D.int4)
    <*> D.column (D.nonNullable D.float8)

listWorkOrders :: Pool -> IO [WorkOrder]
listWorkOrders pool = do
  result <- use pool $ Session.statement () stmt
  case result of
    Right x -> pure x
    Left _ -> pure []
  where
    stmt =
      unpreparable
        "SELECT id, code, dt, due_date, product_id, qtty, status, output_qtty FROM work_order ORDER BY dt DESC"
        E.noParams
        (D.rowList workOrderRow)

createWorkOrder :: Pool -> Text -> Day -> Day -> Int64 -> Double -> IO Int64
createWorkOrder pool code dt due product qty = do
  result <- use pool $ Session.statement params stmt
  case result of
    Right x -> pure x
    Left _ -> pure 0
  where
    params = (code, dt, due, product, qty)
    stmt =
      unpreparable
        "INSERT INTO work_order (code, dt, due_date, product_id, qtty) VALUES ($1,$2,$3,$4,$5) RETURNING id"
        ( E.param (E.nonNullable E.text)
            <> E.param (E.nonNullable E.date)
            <> E.param (E.nonNullable E.date)
            <> E.param (E.nonNullable E.int8)
            <> E.param (E.nonNullable E.float8)
        )
        (D.singleRow $ D.column (D.nonNullable D.int8))

releaseWorkOrder :: Pool -> Int64 -> Day -> IO Bool
releaseWorkOrder pool orderId dt = do
  result <- use pool $ Session.statement (orderId, dt) stmt
  case result of
    Right mb -> pure $ isJust mb
    Left _ -> pure False
  where
    stmt =
      unpreparable
        "SELECT work_order_release($1, $2)"
        ( E.param (E.nonNullable E.int8)
            <> E.param (E.nonNullable E.date)
        )
        (D.singleRow $ D.column (D.nonNullable D.bool))

completeWorkOrder :: Pool -> Int64 -> Double -> IO Bool
completeWorkOrder pool orderId qty = do
  result <- use pool $ Session.statement (orderId, qty) stmt
  case result of
    Right mb -> pure $ isJust mb
    Left _ -> pure False
  where
    stmt =
      unpreparable
        "SELECT work_order_complete($1, $2)"
        ( E.param (E.nonNullable E.int8)
            <> E.param (E.nonNullable E.float8)
        )
        (D.singleRow $ D.column (D.nonNullable D.bool))

listBOMForProduct :: Pool -> Int64 -> IO [BOMEntry]
listBOMForProduct pool productId = do
  result <- use pool $ Session.statement productId stmt
  case result of
    Right x -> pure x
    Left _ -> pure []
  where
    stmt =
      unpreparable
        "SELECT id, product_id, component_id, qtty FROM bom WHERE product_id = $1 ORDER BY id"
        (E.param (E.nonNullable E.int8))
        (D.rowList bomRow)

bomRow :: D.Row BOMEntry
bomRow =
  BOMEntry
    <$> D.column (D.nonNullable D.int8)
    <*> D.column (D.nonNullable D.int8)
    <*> D.column (D.nonNullable D.int8)
    <*> D.column (D.nonNullable D.float8)

calculateMaterialNeed :: Pool -> Int64 -> Double -> IO [MaterialNeed]
calculateMaterialNeed pool productId output = do
  result <- use pool $ Session.statement params stmt
  case result of
    Right x -> pure x
    Left _ -> pure []
  where
    params = (productId, output)
    stmt =
      unpreparable
        "SELECT goods_id, need_qtty FROM calc_material_need($1, $2)"
        ( E.param (E.nonNullable E.int8)
            <> E.param (E.nonNullable E.float8)
        )
        (D.rowList materialNeedRow)

runMRPCalc :: Pool -> [MRPNeed] -> IO [MRPPlanItem]
runMRPCalc pool needs = do
  result <- use pool $ Session.statement payload stmt
  case result of
    Right x -> pure x
    Left _ -> pure []
  where
    payload = (TL.toStrict . decodeUtf8 . toStrict . encode) needs
    stmt =
      unpreparable
        "SELECT goods_id, need_qtty, on_hand, on_order, planned_order FROM mrp_calculate($1::json, CURRENT_DATE)"
        (E.param (E.nonNullable E.text))
        (D.rowList mrpPlanRow)

mrpPlanRow :: D.Row MRPPlanItem
mrpPlanRow =
  MRPPlanItem
    <$> D.column (D.nonNullable D.int8)
    <*> D.column (D.nonNullable D.float8)
    <*> D.column (D.nonNullable D.float8)
    <*> D.column (D.nonNullable D.float8)
    <*> D.column (D.nonNullable D.float8)

listProductionPlanSnapshots :: Pool -> IO [ProductionPlanSnapshot]
listProductionPlanSnapshots pool = do
  result <- use pool $ Session.statement () stmt
  case result of
    Right x -> pure x
    Left _ -> pure []
  where
    stmt =
      unpreparable
        "SELECT id, created_at, plan::text, params FROM production_plan_snapshot ORDER BY created_at DESC LIMIT 20"
        E.noParams
        (D.rowList planSnapshotRow)

planSnapshotRow :: D.Row ProductionPlanSnapshot
planSnapshotRow = do
  iid <- D.column (D.nonNullable D.int8)
  created <- D.column (D.nonNullable D.timestamptz)
  planText <- D.column (D.nonNullable D.text)
  params <- D.column (D.nonNullable D.text)
  let jsonBs = encodeUtf8 (TL.fromStrict planText)
  case eitherDecodeStrict jsonBs of
    Left err -> fail err
    Right plan -> pure $ ProductionPlanSnapshot iid (utctDay created) plan params

logProductionPlan :: Pool -> [MRPPlanItem] -> Text -> IO Int64
logProductionPlan pool plan params = do
  result <- use pool $ Session.statement (planPayload, params) stmt
  case result of
    Right x -> pure x
    Left _ -> pure 0
  where
    planPayload = TL.toStrict . decodeUtf8 . toStrict $ encode plan
    stmt =
      unpreparable
        "INSERT INTO production_plan_snapshot (plan, params) VALUES ($1::jsonb, $2) RETURNING id"
        ( E.param (E.nonNullable E.text)
            <> E.param (E.nonNullable E.text)
        )
        (D.singleRow $ D.column (D.nonNullable D.int8))
