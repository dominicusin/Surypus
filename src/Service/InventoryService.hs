{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE OverloadedStrings #-}

module Service.InventoryService
  ( InventoryService (..),
    createInventoryService,
    processStockReceipt,
    processStockIssue,
    processStockTransfer,
    getStockBalance,
    getStockByLocation,
    getStockByGoods,
    validateStockOperation,
  )
where

import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import Data.Time (Day)
import qualified Hasql.Decoders as D
import qualified Hasql.Encoders as E
import Hasql.Pool (Pool, use)
import qualified Hasql.Session as Session
import Hasql.Statement (Statement)

data InventoryService = InventoryService
  { isPool :: Pool
  }

createInventoryService :: Pool -> InventoryService
createInventoryService = InventoryService

validateStockOperation :: Double -> Either Text ()
validateStockOperation qty
  | qty <= 0 = Left "Quantity must be positive"
  | qty > 1000000 = Left "Quantity exceeds maximum allowed"
  | otherwise = Right ()

processStockReceipt :: InventoryService -> Int64 -> Int64 -> Double -> IO (Either Text Int64)
processStockReceipt service goodsId locationId qty = do
  case validateStockOperation qty of
    Left err -> pure $ Left err
    Right _ -> do
      result <- use (isPool service) $ do
        Session.execute insertStockReceiptStmt (goodsId, locationId, round (qty * 10000))
        Session.query selectLastStockIdStmt () :: Session.Session (Session.Result Int64)
      pure $ case result of
        Left err -> Left (T.pack (show err))
        Right [receiptId] -> Right receiptId
        Right _ -> Left "Failed to get receipt ID"

processStockIssue :: InventoryService -> Int64 -> Int64 -> Double -> IO (Either Text Int64)
processStockIssue service goodsId locationId qty = do
  case validateStockOperation qty of
    Left err -> pure $ Left err
    Right _ -> do
      balanceResult <- getStockBalance service goodsId locationId
      case balanceResult of
        Left err -> pure $ Left err
        Right currentBalance ->
          if currentBalance < qty
            then pure $ Left "Insufficient stock"
            else do
              result <- use (isPool service) $ do
                Session.execute insertStockIssueStmt (goodsId, locationId, round (qty * 10000))
                Session.query selectLastStockIdStmt () :: Session.Session (Session.Result Int64)
              pure $ case result of
                Left err -> Left (T.pack (show err))
                Right [issueId] -> Right issueId
                Right _ -> Left "Failed to get issue ID"

processStockTransfer :: InventoryService -> Int64 -> Int64 -> Int64 -> Double -> IO (Either Text Int64)
processStockTransfer service goodsId fromLocation toLocation qty = do
  case validateStockOperation qty of
    Left err -> pure $ Left err
    Right _ -> do
      balanceResult <- getStockBalance service goodsId fromLocation
      case balanceResult of
        Left err -> pure $ Left err
        Right currentBalance ->
          if currentBalance < qty
            then pure $ Left "Insufficient stock at source location"
            else do
              result <- use (isPool service) $ do
                Session.execute insertStockIssueStmt (goodsId, fromLocation, round (qty * 10000))
                Session.execute insertStockReceiptStmt (goodsId, toLocation, round (qty * 10000))
                Session.query selectLastStockIdStmt () :: Session.Session (Session.Result Int64)
              pure $ case result of
                Left err -> Left (T.pack (show err))
                Right [transferId] -> Right transferId
                Right _ -> Left "Failed to get transfer ID"

getStockBalance :: InventoryService -> Int64 -> Int64 -> IO (Either Text Double)
getStockBalance service goodsId locationId = do
  result <- use (isPool service) $ Session.query selectStockBalanceStmt
    ( goodsId
    , locationId
    )
  pure $ case result of
    Left err -> Left (T.pack (show err))
    Right [] -> Right 0.0
    Right [(bal,)] -> Right (fromIntegral (bal :: Int64) / 10000.0)
    Right _ -> Right 0.0

getStockByLocation :: InventoryService -> Int64 -> IO (Either Text [(Int64, Double)])
getStockByLocation service locationId = do
  result <- use (isPool service) $ Session.query selectStockByLocationStmt
    (locationId)
  pure $ case result of
    Left err -> Left (T.pack (show err))
    Right rows -> Right [(g, fromIntegral (q :: Int64) / 10000.0) | (g, q) <- rows]

getStockByGoods :: InventoryService -> Int64 -> IO (Either Text [(Int64, Double)])
getStockByGoods service goodsId = do
  result <- use (isPool service) $ Session.query selectStockByGoodsStmt
    (goodsId)
  pure $ case result of
    Left err -> Left (T.pack (show err))
    Right rows -> Right [(l, fromIntegral (q :: Int64) / 10000.0) | (l, q) <- rows]

insertStockReceiptStmt :: Statement (Int64, Int64, Int64) Int64
insertStockReceiptStmt =
  Session.statement
    "INSERT INTO stock (goods_id, location_id, qty) VALUES ($1, $2, $3) ON CONFLICT (goods_id, location_id) DO UPDATE SET qty = stock.qty + EXCLUDED.qty RETURNING id"
    ( (,,)
        <$> (E.param (E.nonNullable E.int8))
        <*> (E.param (E.nonNullable E.int8))
        <*> (E.param (E.nonNullable E.int8))
    )
    (D.singleRow (D.column D.nonNullable D.int8))

insertStockIssueStmt :: Statement (Int64, Int64, Int64) Int64
insertStockIssueStmt =
  Session.statement
    "INSERT INTO stock (goods_id, location_id, qty) VALUES ($1, $2, -$3) ON CONFLICT (goods_id, location_id) DO UPDATE SET qty = stock.qty - EXCLUDED.qty RETURNING id"
    ( (,,)
        <$> (E.param (E.nonNullable E.int8))
        <*> (E.param (E.nonNullable E.int8))
        <*> (E.param (E.nonNullable E.int8))
    )
    (D.singleRow (D.column D.nonNullable D.int8))

selectLastStockIdStmt :: Statement () Int64
selectLastStockIdStmt =
  Session.statement
    "SELECT currval('stock_id_seq')"
    Session.noParams
    (D.singleRow (D.column D.nonNullable D.int8))

selectStockBalanceStmt :: Statement (Int64, Int64) (Int64,)
selectStockBalanceStmt =
  Session.statement
    "SELECT COALESCE(qty, 0) FROM stock WHERE goods_id = $1 AND location_id = $2"
    ( (,)
        <$> (E.param (E.nonNullable E.int8))
        <*> (E.param (E.nonNullable E.int8))
    )
    (D.singleRow (D.column D.nonNullable D.int8))

selectStockByLocationStmt :: Statement Int64 [(Int64, Int64)]
selectStockByLocationStmt =
  Session.statement
    "SELECT goods_id, qty FROM stock WHERE location_id = $1 AND qty > 0"
    (E.param (E.nonNullable E.int8))
    ( D.rowList
        ( D.column D.nonNullable D.int8
        , D.column D.nonNullable D.int8
        )
    )

selectStockByGoodsStmt :: Statement Int64 [(Int64, Int64)]
selectStockByGoodsStmt =
  Session.statement
    "SELECT location_id, qty FROM stock WHERE goods_id = $1 AND qty > 0"
    (E.param (E.nonNullable E.int8))
    ( D.rowList
        ( D.column D.nonNullable D.int8
        , D.column D.nonNullable D.int8
        )
    )
