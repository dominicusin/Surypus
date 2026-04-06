{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards #-}

module DB.Inventory
  ( listInventoryDocs,
    getInventoryDoc,
    createInventoryDoc,
    listInventoryLines,
    addInventoryLine,
    getInventorySummary,
    updateInventoryStatus,
  )
where

import Core.Inventory.Types.Inventory (InventoryStatus (..))
import Data.Int (Int32, Int64)
import Data.Text (Text)
import qualified Data.Text as T
import Data.Time (Day)
import Domain.Inventory
import Domain.Types (Pagination (..))
import qualified Hasql.Decoders as D
import qualified Hasql.Encoders as E
import Hasql.Pool (Pool, use)
import qualified Hasql.Session as Session
import Hasql.Statement (Statement)

listInventoryDocs :: Pool -> Pagination -> IO [InventoryDocument]
listInventoryDocs pool Pagination {..} = do
  result <- use pool $ Session.statement (paginationLimit, paginationOffset) stmt
  case result of
    Right x -> pure x
    Left _ -> pure []
  where
    stmt =
      Statement
        "SELECT id, code, dt, warehouse_id, status, memo, created_by, created_at, updated_at FROM inventory_doc ORDER BY dt DESC LIMIT $1 OFFSET $2"
        ( E.param (E.nonNullable E.int4)
            <> E.param (E.nonNullable E.int4)
        )
        (D.rowList inventoryDocRow)

getInventoryDoc :: Pool -> Int64 -> IO (Maybe InventoryDocument)
getInventoryDoc pool docId = do
  result <- use pool $ Session.statement docId stmt
  case result of
    Right x -> pure x
    Left _ -> pure Nothing
  where
    stmt =
      Statement
        "SELECT id, code, dt, warehouse_id, status, memo, created_by, created_at, updated_at FROM inventory_doc WHERE id = $1"
        (E.param (E.nonNullable E.int8))
        (D.rowMaybe inventoryDocRow)

createInventoryDoc :: Pool -> InventoryDocumentInput -> IO (Either Text InventoryDocument)
createInventoryDoc pool InventoryDocumentInput {..} = do
  result <- use pool $ Session.statement params stmt
  case result of
    Right x -> pure $ Right x
    Left err -> (pure . Left) . T.pack $ show err
  where
    params = (idiCode, idiDate, idiWarehouseId, inventoryStatusToInt IS_Draft, idiMemo, idiCreatedBy)
    stmt =
      Statement
        "INSERT INTO inventory_doc (code, dt, warehouse_id, status, memo, created_by) VALUES ($1, $2, $3, $4, $5, $6) RETURNING id, code, dt, warehouse_id, status, memo, created_by, created_at, updated_at"
        ( E.param (E.nonNullable E.text)
            <> E.param (E.nonNullable E.date)
            <> E.param (E.nonNullable E.int8)
            <> E.param (E.nonNullable E.int4)
            <> E.param (E.nullable E.text)
            <> E.param (E.nullable E.int8)
        )
        (D.rowOne inventoryDocRow)

listInventoryLines :: Pool -> Int64 -> IO [InventoryLine]
listInventoryLines pool docId = do
  result <- use pool $ Session.statement docId stmt
  case result of
    Right x -> pure x
    Left _ -> pure []
  where
    stmt =
      Statement
        "SELECT id, inventory_id, line_no, goods_id, unit_id, qtty_booked, qtty_fact, diff, diff_amount, price, flags FROM inventory_line WHERE inventory_id = $1 ORDER BY line_no"
        (E.param (E.nonNullable E.int8))
        (D.rowList inventoryLineRow)

addInventoryLine :: Pool -> InventoryLineInput -> IO (Either Text InventoryLine)
addInventoryLine pool InventoryLineInput {..} = do
  result <- use pool $ Session.statement params stmt
  case result of
    Right x -> pure $ Right x
    Left err -> (pure . Left) . T.pack $ show err
  where
    params = (iliInventoryId, iliLineNo, iliGoodsId, iliUnitId, iliExpectedQtty, iliActualQtty, iliPrice)
    stmt =
      Statement
        "INSERT INTO inventory_line (inventory_id, line_no, goods_id, unit_id, qtty_booked, qtty_fact, price) VALUES ($1, $2, $3, $4, $5, $6, $7) RETURNING id, inventory_id, line_no, goods_id, unit_id, qtty_booked, qtty_fact, diff, diff_amount, price, flags"
        ( E.param (E.nonNullable E.int8)
            <> E.param (E.nonNullable E.int4)
            <> E.param (E.nonNullable E.int8)
            <> E.param (E.nullable E.int8)
            <> E.param (E.nonNullable E.float8)
            <> E.param (E.nonNullable E.float8)
            <> E.param (E.nonNullable E.float8)
        )
        (D.rowOne inventoryLineRow)

getInventorySummary :: Pool -> Int64 -> IO (Maybe InventorySummary)
getInventorySummary pool docId = do
  result <- use pool $ Session.statement docId stmt
  case result of
    Right x -> pure x
    Left _ -> pure Nothing
  where
    stmt =
      Statement
        "SELECT sum_booked::double precision, sum_fact::double precision, sum_diff::double precision, sum_surplus::double precision, sum_shortage::double precision, item_count::int8, surplus_count::int8, shortage_count::int8, exact_count::int8 FROM inventory_summary($1)"
        (E.param (E.nonNullable E.int8))
        (D.rowMaybe inventorySummaryRow)

updateInventoryStatus :: Pool -> Int64 -> InventoryStatus -> IO Bool
updateInventoryStatus pool docId status = do
  result <- use pool $ Session.statement params stmt
  case result of
    Right _ -> pure True
    Left _ -> pure False
  where
    params = (docId, inventoryStatusToInt status)
    stmt =
      Statement
        "UPDATE inventory_doc SET status = $2, updated_at = NOW() WHERE id = $1 RETURNING id"
        ( E.param (E.nonNullable E.int8)
            <> E.param (E.nonNullable E.int4)
        )
        (D.rowMaybe (D.column (D.nonNullable D.int8)))

inventoryDocRow :: D.Row InventoryDocument
inventoryDocRow =
  InventoryDocument
    <$> D.column (D.nonNullable D.int8)
    <*> D.column (D.nonNullable D.text)
    <*> D.column (D.nonNullable D.date)
    <*> D.column (D.nonNullable D.int8)
    <*> (inventoryStatusFromInt <$> D.column (D.nonNullable D.int4))
    <*> D.column (D.nullable D.text)
    <*> D.column (D.nullable D.int8)
    <*> D.column (D.nullable D.timestamptz)
    <*> D.column (D.nullable D.timestamptz)

inventoryLineRow :: D.Row InventoryLine
inventoryLineRow =
  InventoryLine
    <$> D.column (D.nonNullable D.int8)
    <*> D.column (D.nonNullable D.int8)
    <*> D.column (D.nonNullable D.int4)
    <*> D.column (D.nonNullable D.int8)
    <*> D.column (D.nullable D.int8)
    <*> D.column (D.nonNullable D.float8)
    <*> D.column (D.nonNullable D.float8)
    <*> D.column (D.nonNullable D.float8)
    <*> D.column (D.nonNullable D.float8)
    <*> D.column (D.nonNullable D.float8)
    <*> D.column (D.nonNullable D.int4)

inventorySummaryRow :: D.Row InventorySummary
inventorySummaryRow =
  InventorySummary
    <$> D.column (D.nonNullable D.float8)
    <*> D.column (D.nonNullable D.float8)
    <*> D.column (D.nonNullable D.float8)
    <*> D.column (D.nonNullable D.float8)
    <*> D.column (D.nonNullable D.float8)
    <*> (fromIntegral <$> D.column (D.nonNullable D.int8))
    <*> (fromIntegral <$> D.column (D.nonNullable D.int8))
    <*> (fromIntegral <$> D.column (D.nonNullable D.int8))
    <*> (fromIntegral <$> D.column (D.nonNullable D.int8))

inventoryStatusFromInt :: Int32 -> InventoryStatus
inventoryStatusFromInt 0 = IS_Draft
inventoryStatusFromInt 1 = IS_InProgress
inventoryStatusFromInt 2 = IS_Counted
inventoryStatusFromInt 3 = IS_Analyzed
inventoryStatusFromInt 4 = IS_Approved
inventoryStatusFromInt 5 = IS_Completed
inventoryStatusFromInt 6 = IS_Cancelled
inventoryStatusFromInt _ = IS_Draft

inventoryStatusToInt :: InventoryStatus -> Int32
inventoryStatusToInt IS_Draft = 0
inventoryStatusToInt IS_InProgress = 1
inventoryStatusToInt IS_Counted = 2
inventoryStatusToInt IS_Analyzed = 3
inventoryStatusToInt IS_Approved = 4
inventoryStatusToInt IS_Completed = 5
inventoryStatusToInt IS_Cancelled = 6
