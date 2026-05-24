{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE Arrows #-}
{-# LANGUAGE TypeOperators #-}

-- | Stored Procedure Wrappers for PostgreSQL
--
-- This module provides Haskell wrappers for SQL stored procedures
-- defined in sql/procedures.sql. Each wrapper calls the corresponding
-- database function through Opaleye.
--
-- = Usage
--
-- Replace raw SQL queries with stored procedure calls:
--
-- > -- Instead of:
-- > "SELECT * FROM persons WHERE id = $1"
-- >
-- > -- Use:
-- > spPersonRead pool personId
--
module DAL.Procedures where

import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import Data.Functor.Contravariant ((>$<))
import Data.Profunctor.Product.Default (Default)
import qualified Database.PostgreSQL.Simple as PGS
import qualified Opaleye as OE
import qualified Opaleye.Internal.HaskellDB.PrimQuery as OPQ
import qualified Opaleye.Internal.PGTypes as OPG
import qualified Opaleye.Internal.Tag as OITag
import Surypus.CoreTypes (Decimal   (..))
import DAL.Database (Pool, usePool, runQuery, runCommand)

-- | Helper to create prepared statements
preparable :: Text -> E.Params params -> D.Result result -> Statement params result
preparable sql encoder decoder = 
  Statement (TE.encodeUtf8 sql) encoder decoder True

-- ============================================================================
-- WAREHOUSE / INVENTORY PROCEDURES
-- ============================================================================

-- | Calculate stock balance for goods at location
calcStockBalance :: Pool -> Int64 -> Int64 -> IO (Either Text Decimal)
calcStockBalance pool goodsId locationId = do
   let query = OE.sql 
         "SELECT calc_stock_balance($1, $2)"
         (OE.required . fst *** OE.required . snd)
         (OE.column OE.numeric)
   res <- runQuery pool query (goodsId, locationId)
   case res of
     Left err -> return $ Left err
     [n] -> return $ Right (Decimal (realToFrac n))
     _ -> return $ Left "Expected exactly one row from calc_stock_balance"

-- | Get lot bounds (min/max dates)
getLotBounds :: Pool -> Int64 -> Int64 -> IO (Either Text (Maybe (Text, Text, Decimal)))
getLotBounds pool goodsId locationId = do
   let query = OE.sql 
         "SELECT min_date::text, max_date::text, total_qty FROM get_lot_bounds($1, $2)"
         (OE.required . fst *** OE.required . snd)
         (OE.required . OE.text *** OE.required . OE.text *** OE.column OE.numeric)
   res <- runQuery pool query (goodsId, locationId)
   case res of
     Left err -> return $ Left err
     [] -> return $ Right Nothing
     [(minDate, maxDate, totalQty)] -> return $ Right (Just (minDate, maxDate, Decimal (realToFrac totalQty)))
     _ -> return $ Left "Expected zero or one rows from get_lot_bounds"

-- ============================================================================
-- TAX CALCULATION PROCEDURES
-- ============================================================================

-- | Calculate VAT amount
calcVAT :: Pool -> Double -> Double -> IO (Either Text Double)
calcVAT pool amount rate = do
   let query = OE.sql 
         "SELECT calc_vat($1, $2)"
         (OE.required . fst *** OE.required . snd)
         (OE.column OE.float8)
   res <- runQuery pool query (amount, rate)
   case res of
     Left err -> return $ Left err
     [v] -> return $ Right v
     _ -> return $ Left "Expected exactly one row from calc_vat"

-- | Calculate VAT-inclusive price
calcVATInclusive :: Pool -> Double -> Double -> IO (Either Text Double)
calcVATInclusive pool amount rate = do
  let stmt = preparable
        "SELECT calc_vat_inclusive($1, $2)"
        ((fst >$< E.param (E.nonNullable E.float8)) <> (snd >$< E.param (E.nonNullable E.float8)))
        (D.singleRow (D.column (D.nonNullable D.float8)))
  res <- use pool $ Session.statement (amount, rate) stmt
  case res of
    Right v -> pure $ Right v
    Left err -> pure $ Left (T.pack $ show err)

-- | Calculate price without VAT
calcPriceWithoutVAT :: Pool -> Double -> Double -> IO (Either Text Double)
calcPriceWithoutVAT pool amount rate = do
  let stmt = preparable
        "SELECT calc_price_without_vat($1, $2)"
        ((fst >$< E.param (E.nonNullable E.float8)) <> (snd >$< E.param (E.nonNullable E.float8)))
        (D.singleRow (D.column (D.nonNullable D.float8)))
  res <- use pool $ Session.statement (amount, rate) stmt
  case res of
    Right v -> pure $ Right v
    Left err -> pure $ Left (T.pack $ show err)

-- ============================================================================
-- BILL PROCEDURES
-- ============================================================================

-- | Post a bill (run full posting logic)
postBill :: Pool -> Int64 -> IO (Either Text Bool)
postBill pool billId = do
  let stmt = preparable
        "SELECT post_bill  (..)"
        (E.param (E.nonNullable E.int8))
        (D.singleRow (D.column (D.nonNullable D.bool)))
  res <- use pool $ Session.statement billId stmt
  case res of
    Right v -> pure $ Right v
    Left err -> pure $ Left (T.pack $ show err)

-- | Cancel a bill
cancelBill :: Pool -> Int64 -> IO (Either Text Bool)
cancelBill pool billId = do
  let stmt = preparable
        "SELECT cancel_bill  (..)"
        (E.param (E.nonNullable E.int8))
        (D.singleRow (D.column (D.nonNullable D.bool)))
  res <- use pool $ Session.statement billId stmt
  case res of
    Right v -> pure $ Right v
    Left err -> pure $ Left (T.pack $ show err)

-- ============================================================================
-- ACCOUNTING PROCEDURES
-- ============================================================================

-- | Validate double-entry accounting rules
validateDoubleEntry :: Pool -> Int64 -> IO (Either Text Bool)
validateDoubleEntry pool entryId = do
  let stmt = preparable
        "SELECT validate_double_entry  (..)"
        (E.param (E.nonNullable E.int8))
        (D.singleRow (D.column (D.nonNullable D.bool)))
  res <- use pool $ Session.statement entryId stmt
  case res of
    Right v -> pure $ Right v
    Left err -> pure $ Left (T.pack $ show err)

-- | Calculate account balance
calcAccountBalance :: Pool -> Int64 -> IO (Either Text Decimal)
calcAccountBalance pool accountId = do
  let stmt = preparable
        "SELECT calc_account_balance  (..)"
        (E.param (E.nonNullable E.int8))
        (D.singleRow (fmap (\n -> Decimal (realToFrac n)) (D.column (D.nonNullable D.numeric))))
  res <- use pool $ Session.statement accountId stmt
  case res of
    Right v -> pure $ Right v
    Left err -> pure $ Left (T.pack $ show err)

-- ============================================================================
-- REPORT PROCEDURES
-- ============================================================================

-- | Get sales report for period
getSalesReport :: Pool -> Text -> Text -> IO (Either Text [(Text, Double)])
getSalesReport pool dateFrom dateTo = do
  let stmt = preparable
        "SELECT report_date::text, total_amount FROM get_sales_report($1, $2)"
        ((fst >$< E.param (E.nonNullable E.text)) <> (snd >$< E.param (E.nonNullable E.text)))
        (D.rowList $ (,) <$> D.column (D.nonNullable D.text) <*> D.column (D.nonNullable D.float8))
  res <- use pool $ Session.statement (dateFrom, dateTo) stmt
  case res of
    Right rows -> pure $ Right rows
    Left err -> pure $ Left (T.pack $ show err)