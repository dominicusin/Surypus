{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE OverloadedStrings #-}

module Surypus.API.Production
  ( listTechCards
  , createTechCard
  , getTechCard
  , updateTechCard
  , deleteTechCard
  , listWorkOrders
  , createWorkOrder
  , getWorkOrder
  , updateWorkOrder
  , deleteWorkOrder
  , releaseWorkOrder
  , completeWorkOrder
  ) where

import DAL.Types (QueryResult(..))
import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import Data.Time (UTCTime, Day)
import qualified Opaleye as OE
import qualified Opaleye.Internal.HaskellDB.PrimQuery as OPQ
import qualified Opaleye.Internal.PGTypes as OPG
import qualified Opaleye.Internal.Tag as OITag
import DAL.Database (Pool, runQuery, runCommand)
import Production.Types (TechCard(..), TechLine(..), WorkOrder(..), WorkOrderStatusCode(..))

-- TechCard endpoints
listTechCards :: Pool -> Maybe Int64 -> Maybe Int -> Maybe Int -> IO (QueryResult [TechCard])
listTechCards pool goodsId limitOffset limitCount = do
  result <- use pool $ Session.statement (goodsId, limitOffset, limitCount) selectTechCardsStmt
  return $ case result of
    Left err -> QueryError (T.pack $ show err)
    Right cards -> QuerySuccess cards

selectTechCardsStmt :: Statement (Maybe Int64, Int, Int) [TechCard]
selectTechCardsStmt = Statement sql encoder decoder True
  where
    sql = "SELECT id, goods_id, name, version, status, created_at, updated_at, created_by FROM tech_card WHERE (? IS NULL OR goods_id = ?) ORDER BY id LIMIT ? OFFSET ?"
    encoder =
      ((\(gid, _, _, _) -> gid) >$< E.param (E.nullable E.int8))
        <> ((\(_, gid', _, _) -> gid') >$< E.param (E.nullable E.int8))
        <> ((\(_, _, limit, _) -> limit) >$< E.param (E.nonNullable E.int4))
        <> ((\(_, _, _, offset) -> offset) >$< E.param (E.nonNullable E.int4))
    decoder = D.rowList techCardDecoder

createTechCard :: Pool -> TechCard -> IO (QueryResult TechCard)
createTechCard pool input = do
  result <- use pool $ Session.statement (tgGoodsId input, tgName input, tgVersion input, fromIntegral (tgStatus input), tgCreatedAt input, tgUpdatedAt input, tgCreatedBy input) insertTechCardStmt
  return $ case result of
    Left err -> QueryError (T.pack $ show err)
    Right card -> QuerySuccess card

insertTechCardStmt :: Statement (Int64, Text, Text, Int16, UTCTime, UTCTime, Maybe Text) TechCard
insertTechCardStmt = Statement sql encoder decoder True
  where
    sql = "INSERT INTO tech_card (goods_id, name, version, status, created_at, updated_at, created_by) VALUES ($1, $2, $3, $4, $5, $6, $7) RETURNING id, goods_id, name, version, status, created_at, updated_at, created_by"
    encoder =
      ((\(gid, _, _, _, _, _, _) -> gid) >$< E.param (E.nonNullable E.int8))
        <> ((\(_, name, _, _, _, _, _) -> name) >$< E.param (E.nonNullable E.text))
        <> ((\(_, _, version, _, _, _, _) -> version) >$< E.param (E.nonNullable E.text))
        <> ((\(_, _, _, status, _, _, _) -> (fromIntegral status :: Int16)) >$< E.param (E.nonNullable E.int2))
        <> ((\(_, _, _, _, createdAt, _, _) -> createdAt) >$< E.param (E.nonNullable E.utcTime))
        <> ((\(_, _, _, _, _, updatedAt, _) -> updatedAt) >$< E.param (E.nonNullable E.utcTime))
        <> ((\(_, _, _, _, _, _, createdBy) -> createdBy) >$< E.param (E.nullable E.text))
    decoder = D.singleRow techCardDecoder

getTechCard :: Pool -> Int64 -> IO (QueryResult TechCard)
getTechCard pool tcId = do
  result <- use pool $ Session.statement tcId selectTechCardStmt
  return $ case result of
    Left err -> QueryError (T.pack $ show err)
    Right card -> QuerySuccess card

selectTechCardStmt :: Statement Int64 TechCard
selectTechCardStmt = Statement sql encoder decoder True
  where
    sql = "SELECT id, goods_id, name, version, status, created_at, updated_at, created_by FROM tech_card WHERE id = $1"
    encoder = ((\(tcid) -> tcid) >$< E.param (E.nonNullable E.int8))
    decoder = D.singleRow techCardDecoder

updateTechCard :: Pool -> Int64 -> TechCard -> IO (QueryResult TechCard)
updateTechCard pool tcId input = do
  result <- use pool $ Session.statement (tgName input, tgVersion input, fromIntegral (tgStatus input), tgUpdatedAt input, tgCreatedBy input, tcId) updateTechCardStmt
  return $ case result of
    Left err -> QueryError (T.pack $ show err)
    Right card -> QuerySuccess card

updateTechCardStmt :: Statement (Text, Text, Int16, UTCTime, Maybe Text, Int64) TechCard
updateTechCardStmt = Statement sql encoder decoder True
  where
    sql = "UPDATE tech_card SET name = $1, version = $2, status = $3, updated_at = $4, created_by = $5 WHERE id = $6 RETURNING id, goods_id, name, version, status, created_at, updated_at, created_by"
    encoder =
      ((\(name, _, _, _, _, _) -> name) >$< E.param (E.nonNullable E.text))
        <> ((\(_, version, _, _, _, _) -> version) >$< E.param (E.nonNullable E.text))
        <> ((\(_, _, status, _, _, _) -> (fromIntegral status :: Int16)) >$< E.param (E.nonNullable E.int2))
        <> ((\(_, _, _, updatedAt, _, _) -> updatedAt) >$< E.param (E.nonNullable E.utcTime))
        <> ((\(_, _, _, _, createdBy, _) -> createdBy) >$< E.param (E.nullable E.text))
        <> ((\(_, _, _, _, _, tcId) -> tcId) >$< E.param (E.nonNullable E.int8))
    decoder = D.singleRow techCardDecoder

deleteTechCard :: Pool -> Int64 -> IO (QueryResult ())
deleteTechCard pool tcId = do
  result <- use pool $ Session.statement tcId deleteTechCardStmt
  return $ case result of
    Left err -> QueryError (T.pack $ show err)
    Right () -> QuerySuccess ()

deleteTechCardStmt :: Statement Int64 ()
deleteTechCardStmt = Statement sql encoder decoder True
  where
    sql = "DELETE FROM tech_card WHERE id = $1"
    encoder = ((\(tcid) -> tcid) >$< E.param (E.nonNullable E.int8))
    decoder = D.noResult

techCardDecoder :: D.Row TechCard
techCardDecoder =
  TechCard
    <$> D.column (D.nullable D.int8)
    <*> D.column (D.nonNullable D.int8)
    <*> D.column (D.nonNullable D.text)
    <*> D.column (D.nonNullable D.text)
    <*> (fromIntegral <$> D.column (D.nonNullable D.int2))
    <*> D.column (D.nonNullable D.utcTime)
    <*> D.column (D.nonNullable D.utcTime)
    <*> D.column (D.nullable D.text)

-- WorkOrder endpoints
listWorkOrders :: Pool -> Maybe Int64 -> Maybe Int -> Maybe Int -> IO (QueryResult [WorkOrder])
listWorkOrders pool goodsId limitOffset limitCount = do
  result <- use pool $ Session.statement (goodsId, limitOffset, limitCount) selectWorkOrdersStmt
  return $ case result of
    Left err -> QueryError (T.pack $ show err)
    Right orders -> QuerySuccess orders

selectWorkOrdersStmt :: Statement (Maybe Int64, Int, Int) [WorkOrder]
selectWorkOrdersStmt = Statement sql encoder decoder True
  where
    sql = "SELECT id, code, goods_id, tech_card_id, qty_plan, qty_released, status, start_date, end_date, processor_id, notes, created_at, updated_at, created_by FROM work_order WHERE (? IS NULL OR goods_id = ?) ORDER BY id LIMIT ? OFFSET ?"
    encoder =
      ((\(gid, _, _, _, _, _, _, _, _, _, _, _, _, _, _) -> gid) >$< E.param (E.nullable E.int8))
        <> ((\(_, gid', _, _, _, _, _, _, _, _, _, _, _, _, _) -> gid') >$< E.param (E.nullable E.int8))
        <> ((\(_, _, limit, _, _, _, _, _, _, _, _, _, _, _, _, _) -> limit) >$< E.param (E.nonNullable E.int4))
        <> ((\(_, _, _, offset, _, _, _, _, _, _, _, _, _, _, _, _) -> offset) >$< E.param (E.nonNullable E.int4))
    decoder = D.rowList workOrderDecoder

createWorkOrder :: Pool -> WorkOrder -> IO (QueryResult WorkOrder)
createWorkOrder pool input = do
  result <- use pool $ Session.statement (woCode input, woGoodsId input, woTechCardId input, woQtyPlan input, woQtyReleased input, fromIntegral (woStatus input), woStartDate input, woEndDate input, woProcessorId input, woNotes input, woCreatedAt input, woUpdatedAt input, woCreatedBy input) insertWorkOrderStmt
  return $ case result of
    Left err -> QueryError (T.pack $ show err)
    Right order -> QuerySuccess order

insertWorkOrderStmt :: Statement (Text, Int64, Maybe Int64, Double, Double, Int16, Maybe Day, Maybe Day, Maybe Int64, Maybe Text, UTCTime, UTCTime, Maybe Text) WorkOrder
insertWorkOrderStmt = Statement sql encoder decoder True
  where
    sql = "INSERT INTO work_order (code, goods_id, tech_card_id, qty_plan, qty_released, status, start_date, end_date, processor_id, notes, created_at, updated_at, created_by) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13) RETURNING id, code, goods_id, tech_card_id, qty_plan, qty_released, status, start_date, end_date, processor_id, notes, created_at, updated_at, created_by"
    encoder =
      ((\(code, _, _, _, _, _, _, _, _, _, _, _, _, _) -> code) >$< E.param (E.nonNullable E.text))
        <> ((\(_, goodsId, _, _, _, _, _, _, _, _, _, _, _, _) -> goodsId) >$< E.param (E.nonNullable E.int8))
        <> ((\(_, _, techCardId, _, _, _, _, _, _, _, _, _, _, _, _) -> techCardId) >$< E.param (E.nullable E.int8))
        <> ((\(_, _, _, qtyPlan, _, _, _, _, _, _, _, _, _, _, _) -> qtyPlan) >$< E.param (E.nonNullable E.numeric))
        <> ((\(_, _, _, _, qtyReleased, _, _, _, _, _, _, _, _, _, _) -> qtyReleased) >$< E.param (E.nonNullable E.numeric))
        <> ((\(_, _, _, _, _, status, _, _, _, _, _, _, _, _) -> (fromIntegral status :: Int16)) >$< E.param (E.nonNullable E.int2))
        <> ((\(_, _, _, _, _, _, startDate, _, _, _, _, _, _, _) -> startDate) >$< E.param (E.nullable E.date))
        <> ((\(_, _, _, _, _, _, _, endDate, _, _, _, _, _, _, _) -> endDate) >$< E.param (E.nullable E.date))
        <> ((\(_, _, _, _, _, _, _, _, processorId, _, _, _, _, _) -> processorId) >$< E.param (E.nullable E.int8))
        <> ((\(_, _, _, _, _, _, _, _, _, notes, _, _, _, _) -> notes) >$< E.param (E.nullable E.text))
        <> ((\(_, _, _, _, _, _, _, _, _, _, createdAt, _, _, _) -> createdAt) >$< E.param (E.nonNullable E.utcTime))
        <> ((\(_, _, _, _, _, _, _, _, _, _, _, updatedAt, _, _) -> updatedAt) >$< E.param (E.nonNullable E.utcTime))
        <> ((\(_, _, _, _, _, _, _, _, _, _, _, _, createdBy, _) -> createdBy) >$< E.param (E.nullable E.text))
    decoder = D.singleRow workOrderDecoder

getWorkOrder :: Pool -> Int64 -> IO (QueryResult WorkOrder)
getWorkOrder pool woId = do
  result <- use pool $ Session.statement woId selectWorkOrderStmt
  return $ case result of
    Left err -> QueryError (T.pack $ show err)
    Right order -> QuerySuccess order

selectWorkOrderStmt :: Statement Int64 WorkOrder
selectWorkOrderStmt = Statement sql encoder decoder True
  where
    sql = "SELECT id, code, goods_id, tech_card_id, qty_plan, qty_released, status, start_date, end_date, processor_id, notes, created_at, updated_at, created_by FROM work_order WHERE id = $1"
    encoder = ((\(woid) -> woid) >$< E.param (E.nonNullable E.int8))
    decoder = D.singleRow workOrderDecoder

updateWorkOrder :: Pool -> Int64 -> WorkOrder -> IO (QueryResult WorkOrder)
updateWorkOrder pool woId input = do
  result <- use pool $ Session.statement (woCode input, woGoodsId input, woTechCardId input, woQtyPlan input, woQtyReleased input, fromIntegral (woStatus input), woStartDate input, woEndDate input, woProcessorId input, woNotes input, woUpdatedAt input, woCreatedBy input, woId) updateWorkOrderStmt
  return $ case result of
    Left err -> QueryError (T.pack $ show err)
    Right order -> QuerySuccess order

updateWorkOrderStmt :: Statement (Text, Int64, Maybe Int64, Double, Double, Int16, Maybe Day, Maybe Day, Maybe Int64, Maybe Text, UTCTime, UTCTime, Maybe Text, Int64) WorkOrder
updateWorkOrderStmt = Statement sql encoder decoder True
  where
    sql = "UPDATE work_order SET code = $1, goods_id = $2, tech_card_id = $3, qty_plan = $4, qty_released = $5, status = $6, start_date = $7, end_date = $8, processor_id = $9, notes = $10, updated_at = $11, created_by = $12 WHERE id = $13 RETURNING id, code, goods_id, tech_card_id, qty_plan, qty_released, status, start_date, end_date, processor_id, notes, created_at, updated_at, created_by"
    encoder =
      ((\(code, _, _, _, _, _, _, _, _, _, _, _, _, _) -> code) >$< E.param (E.nonNullable E.text))
        <> ((\(_, goodsId, _, _, _, _, _, _, _, _, _, _, _, _, _) -> goodsId) >$< E.param (E.nonNullable E.int8))
        <> ((\(_, _, techCardId, _, _, _, _, _, _, _, _, _, _, _, _, _) -> techCardId) >$< E.param (E.nullable E.int8))
        <> ((\(_, _, _, qtyPlan, _, _, _, _, _, _, _, _, _, _, _, _) -> qtyPlan) >$< E.param (E.nonNullable E.numeric))
        <> ((\(_, _, _, _, qtyReleased, _, _, _, _, _, _, _, _, _, _, _) -> qtyReleased) >$< E.param (E.nonNullable E.numeric))
        <> ((\(_, _, _, _, _, status, _, _, _, _, _, _, _, _, _) -> (fromIntegral status :: Int16)) >$< E.param (E.nonNullable E.int2))
        <> ((\(_, _, _, _, _, _, startDate, _, _, _, _, _, _, _, _) -> startDate) >$< E.param (E.nullable E.date))
        <> ((\(_, _, _, _, _, _, _, endDate, _, _, _, _, _, _, _) -> endDate) >$< E.param (E.nullable E.date))
        <> ((\(_, _, _, _, _, _, _, _, processorId, _, _, _, _, _, _) -> processorId) >$< E.param (E.nullable E.int8))
        <> ((\(_, _, _, _, _, _, _, _, _, notes, _, _, _, _, _) -> notes) >$< E.param (E.nullable E.text))
        <> ((\(_, _, _, _, _, _, _, _, _, _, updatedAt, _, _, _) -> updatedAt) >$< E.param (E.nonNullable E.utcTime))
        <> ((\(_, _, _, _, _, _, _, _, _, _, _, createdBy, _, _) -> createdBy) >$< E.param (E.nullable E.text))
        <> ((\(_, _, _, _, _, _, _, _, _, _, _, _, woId, _) -> woId) >$< E.param (E.nonNullable E.int8))
    decoder = D.singleRow workOrderDecoder

deleteWorkOrder :: Pool -> Int64 -> IO (QueryResult ())
deleteWorkOrder pool woId = do
  result <- use pool $ Session.statement woId deleteWorkOrderStmt
  return $ case result of
    Left err -> QueryError (T.pack $ show err)
    Right () -> QuerySuccess ()

deleteWorkOrderStmt :: Statement Int64 ()
deleteWorkOrderStmt = Statement sql encoder decoder True
  where
    sql = "DELETE FROM work_order WHERE id = $1"
    encoder = ((\(woid) -> woid) >$< E.param (E.nonNullable E.int8))
    decoder = D.noResult

releaseWorkOrder :: Pool -> Int64 -> UTCTime -> Text -> IO (QueryResult WorkOrder)
releaseWorkOrder pool woId releaseTime userId = do
  -- In a real implementation, we'd call the service layer here
  -- For now, we'll directly update the status to released (1)
  result <- use pool $ Session.statement (fromIntegral (1 :: Int16), Just releaseTime, Nothing, userId, woId) releaseWorkOrderStmt
  return $ case result of
    Left err -> QueryError (T.pack $ show err)
    Right order -> QuerySuccess order

releaseWorkOrderStmt :: Statement (Int16, Maybe UTCTime, Maybe UTCTime, Maybe Text, Int64) WorkOrder
releaseWorkOrderStmt = Statement sql encoder decoder True
  where
    sql = "UPDATE work_order SET status = $1, start_at = $2, updated_at = $3, updated_by = $4 WHERE id = $5 RETURNING id, code, goods_id, tech_card_id, qty_plan, qty_released, status, start_date, end_date, processor_id, notes, created_at, updated_at, created_by"
    encoder =
      ((\(status, _, _, _, _) -> status) >$< E.param (E.nonNullable E.int2))
        <> ((\(_, startTime, _, _, _) -> startTime) >$< E.param (E.nullable E.utcTime))
        <> ((\(_, _, updatedAt, _, _, _) -> updatedAt) >$< E.param (E.nonNullable E.utcTime))
        <> ((\(_, _, _, updatedBy, _, _) -> updatedBy) >$< E.param (E.nullable E.text))
        <> ((\(_, _, _, _, woId) -> woId) >$< E.param (E.nonNullable E.int8))
    decoder = D.singleRow workOrderDecoder

completeWorkOrder :: Pool -> Int64 -> UTCTime -> Text -> IO (QueryResult WorkOrder)
completeWorkOrder pool woId completionTime userId = do
  -- In a real implementation, we'd call the service layer here
  -- For now, we'll directly update the status to completed (2)
  result <- use pool $ Session.statement (fromIntegral (2 :: Int16), Nothing, Just completionTime, userId, woId) completeWorkOrderStmt
  return $ case result of
    Left err -> QueryError (T.pack $ show err)
    Right order -> QuerySuccess order

completeWorkOrderStmt :: Statement (Int16, Maybe UTCTime, Maybe UTCTime, Maybe Text, Int64) WorkOrder
completeWorkOrderStmt = Statement sql encoder decoder True
  where
    sql = "UPDATE work_order SET status = $1, start_at = start_at, end_at = $2, updated_at = $3, updated_by = $4 WHERE id = $5 RETURNING id, code, goods_id, tech_card_id, qty_plan, qty_released, status, start_date, end_date, processor_id, notes, created_at, updated_at, created_by"
    encoder =
      ((\(status, _, _, _, _) -> status) >$< E.param (E.nonNullable E.int2))
        <> ((\(_, _, endTime, _, _, _) -> endTime) >$< E.param (E.nullable E.utcTime))
        <> ((\(_, _, _, updatedAt, _, _) -> updatedAt) >$< E.param (E.nonNullable E.utcTime))
        <> ((\(_, _, _, updatedBy, _, _) -> updatedBy) >$< E.param (E.nullable E.text))
        <> ((\(_, _, _, _, woId) -> woId) >$< E.param (E.nonNullable E.int8))
    decoder = D.singleRow workOrderDecoder

workOrderDecoder :: D.Row WorkOrder
workOrderDecoder =
  WorkOrder
    <$> D.column (D.nullable D.int8)
    <*> D.column (D.nonNullable D.text)
    <*> D.column (D.nonNullable D.int8)
    <*> D.column (D.nullable D.int8)
    <*> D.column (D.nonNullable D.numeric)
    <*> D.column (D.nonNullable D.numeric)
    <*> (fromIntegral <$> D.column (D.nonNullable D.int2))
    <*> D.column (D.nullable D.day)
    <*> D.column (D.nullable D.day)
    <*> D.column (D.nullable D.int8)
    <*> D.column (D.nullable D.text)
    <*> D.column (D.nonNullable D.utcTime)
    <*> D.column (D.nonNullable D.utcTime)
    <*> D.column (D.nullable D.text)