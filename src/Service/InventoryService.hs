{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE OverloadedStrings #-}

-- | Inventory/stock management service.
--
-- Provides stock operations including receipts, issues, transfers, and balance queries.
-- All stock quantities are stored as integers (multiplied by 10000 for precision) and
-- converted to/from 'Double' at the API boundary.
--
-- Example usage:
--
-- @
-- service <- createInventoryService pool
-- case processStockReceipt service goodsId locationId 100.0 of
--   Right receiptId -> putStrLn $ "Receipt created: " ++ show receiptId
--   Left err        -> putStrLn $ "Error: " ++ show err
-- @
module Service.InventoryService
  ( -- * Service type
    InventoryService (..),
    createInventoryService,

    -- * Stock operations
    processStockReceipt,
    processStockIssue,
    processStockTransfer,

    -- * Stock queries
    getStockBalance,
    getStockByLocation,
    getStockByGoods,

    -- * Validation
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

-- | Inventory service with database connection pool
newtype InventoryService = InventoryService
  { isPool :: Pool
  }

-- | Create a new inventory service
createInventoryService :: Pool -> InventoryService
createInventoryService = InventoryService

-- | Validate stock operation parameters
validateStockOperation :: Double -> Either Text ()
validateStockOperation qty
  | qty <= 0 = Left "Quantity must be positive"
  | qty > 1000000 = Left "Quantity exceeds maximum allowed"
  | otherwise = Right ()

-- | Process stock receipt (goods incoming)
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

-- | Process stock issue (goods outgoing)
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

-- | Process stock transfer between locations
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

-- | Get current stock balance for goods at location
getStockBalance :: InventoryService -> Int64 -> Int64 -> IO (Either Text Double)
getStockBalance service goodsId locationId = do
  result <- use (isPool service) $ Session.query selectStockBalanceStmt
    ( goodsId
    , locationId
    )
   pure $ case result of
     Left err -> Left (T.pack (show err))
     Right [] -> Right 0.0
     Right [(bal, _)] -> Right (fromIntegral (bal :: Int64) / 10000.0)
     Right _ -> Right 0.0

-- | Get all stock at a location (returns goods IDs with quantities)
getStockByLocation :: InventoryService -> Int64 -> IO (Either Text [(Int64, Double)])
getStockByLocation service locationId = do
  result <- use (isPool service) $ Session.query selectStockByLocationStmt
    (locationId)
  pure $ case result of
    Left err -> Left (T.pack (show err))
    Right rows -> Right [(g, fromIntegral (q :: Int64) / 10000.0) | (g, q) <- rows]

-- | Get all stock for a goods item (returns location IDs with quantities)
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
    (D.singleRow (D.column (D.nonNullable D.int8)))

insertStockIssueStmt :: Statement (Int64, Int64, Int64) Int64
insertStockIssueStmt =
  Session.statement
    "INSERT INTO stock (goods_id, location_id, qty) VALUES ($1, $2, -$3) ON CONFLICT (goods_id, location_id) DO UPDATE SET qty = stock.qty - EXCLUDED.qty RETURNING id"
    ( (,,)
        <$> (E.param (E.nonNullable E.int8))
        <*> (E.param (E.nonNullable E.int8))
        <*> (E.param (E.nonNullable E.int8))
    )
    (D.singleRow (D.column (D.nonNullable D.int8)))

selectLastStockIdStmt :: Statement () Int64
selectLastStockIdStmt =
  Session.statement
    "SELECT currval('stock_id_seq')"
    Session.noParams
    (D.singleRow (D.column (D.nonNullable D.int8)))

selectStockBalanceStmt :: Statement (Int64, Int64) (Int64,)
selectStockBalanceStmt =
  Session.statement
    "SELECT COALESCE(qty, 0) FROM stock WHERE goods_id = $1 AND location_id = $2"
    ( (,) <$> E.param (E.nonNullable E.int8) <*> E.param (E.nonNullable E.int8) )
    (D.singleRow (D.column (D.nonNullable D.int8)))

selectStockByLocationStmt :: Statement Int64 [(Int64, Int64)]
selectStockByLocationStmt =
  Session.statement
    "SELECT goods_id, qty FROM stock WHERE location_id = $1 AND qty > 0"
    (E.param (E.nonNullable E.int8))
    ( D.rowList
        ( D.column (D.nonNullable D.int8)
        , D.column (D.nonNullable D.int8)
        )
    )

selectStockByGoodsStmt :: Statement Int64 [(Int64, Int64)]
selectStockByGoodsStmt =
  Session.statement
    "SELECT location_id, qty FROM stock WHERE goods_id = $1 AND qty > 0"
    (E.param (E.nonNullable E.int8))
    ( D.rowList
        ( D.column (D.nonNullable D.int8)
        , D.column (D.nonNullable D.int8)
        )
    )
