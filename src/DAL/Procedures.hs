{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

module DAL.Procedures where

import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.Encoding as TE
import Data.Functor.Contravariant ((>$<))
import qualified Hasql.Decoders as D
import qualified Hasql.Encoders as E
import qualified Hasql.Statement as Statement
import qualified Hasql.Session as Session
import Surypus.CoreTypes (Decimal (..))
import DAL.Database (Pool, usePool)
import DAL.Types (QueryResult(..))
import Data.Maybe (listToMaybe)

preparable :: Text -> E.Params params -> D.Result result -> Statement.Statement params result
preparable sql encoder decoder = 
  Statement.Statement (TE.encodeUtf8 sql) encoder decoder True

calcStockBalance :: Pool -> Int64 -> Int64 -> IO (QueryResult Decimal)
calcStockBalance pool goodsId locationId = do
  let stmt = preparable
        "SELECT calc_stock_balance($1, $2)"
        ((fst >$< E.param (E.nonNullable E.int8)) <> (snd >$< E.param (E.nonNullable E.int8)))
        (D.singleRow (fmap (\n -> Decimal (realToFrac n)) (D.column (D.nonNullable D.numeric))))
  res <- usePool pool $ Session.statement (goodsId, locationId) stmt
  case res of
    Right v -> pure $ QuerySuccess v
    Left err -> pure $ QueryError (T.pack $ show err)

getLotBounds :: Pool -> Int64 -> Int64 -> IO (QueryResult (Maybe (Text, Text, Decimal)))
getLotBounds pool goodsId locationId = do
  let stmt = preparable
        "SELECT min_date::text, max_date::text, total_qty FROM get_lot_bounds($1, $2)"
        ((fst >$< E.param (E.nonNullable E.int8)) <> (snd >$< E.param (E.nonNullable E.int8)))
        (D.rowMaybe $ (,,) 
          <$> (D.column (D.nonNullable D.text))
          <*> (D.column (D.nonNullable D.text))
          <*> (fmap (\n -> Decimal (realToFrac n)) (D.column (D.nonNullable D.numeric))))
  res <- usePool pool $ Session.statement (goodsId, locationId) stmt
  case res of
    Right mb -> pure $ QuerySuccess mb
    Left err -> pure $ QueryError (T.pack $ show err)

calcVAT :: Pool -> Double -> Double -> IO (QueryResult Double)
calcVAT pool amount rate = do
  let stmt = preparable
        "SELECT calc_vat($1, $2)"
        ((fst >$< E.param (E.nonNullable E.float8)) <> (snd >$< E.param (E.nonNullable E.float8)))
        (D.singleRow (D.column (D.nonNullable D.float8)))
  res <- usePool pool $ Session.statement (amount, rate) stmt
  case res of
    Right v -> pure $ QuerySuccess v
    Left err -> pure $ QueryError (T.pack $ show err)

calcVATInclusive :: Pool -> Double -> Double -> IO (QueryResult Double)
calcVATInclusive pool amount rate = do
  let stmt = preparable
        "SELECT calc_vat_inclusive($1, $2)"
        ((fst >$< E.param (E.nonNullable E.float8)) <> (snd >$< E.param (E.nonNullable E.float8)))
        (D.singleRow (D.column (D.nonNullable D.float8)))
  res <- usePool pool $ Session.statement (amount, rate) stmt
  case res of
    Right v -> pure $ QuerySuccess v
    Left err -> pure $ QueryError (T.pack $ show err)

calcPriceWithoutVAT :: Pool -> Double -> Double -> IO (QueryResult Double)
calcPriceWithoutVAT pool amount rate = do
  let stmt = preparable
        "SELECT calc_price_without_vat($1, $2)"
        ((fst >$< E.param (E.nonNullable E.float8)) <> (snd >$< E.param (E.nonNullable E.float8)))
        (D.singleRow (D.column (D.nonNullable D.float8)))
  res <- usePool pool $ Session.statement (amount, rate) stmt
  case res of
    Right v -> pure $ QuerySuccess v
    Left err -> pure $ QueryError (T.pack $ show err)

postBill :: Pool -> Int64 -> IO (QueryResult Bool)
postBill pool billId = do
  let stmt = preparable
        "SELECT post_bill($1)"
        (E.param (E.nonNullable E.int8))
        (D.singleRow (D.column (D.nonNullable D.bool)))
  res <- usePool pool $ Session.statement billId stmt
  case res of
    Right v -> pure $ QuerySuccess v
    Left err -> pure $ QueryError (T.pack $ show err)

cancelBill :: Pool -> Int64 -> IO (QueryResult Bool)
cancelBill pool billId = do
  let stmt = preparable
        "SELECT cancel_bill($1)"
        (E.param (E.nonNullable E.int8))
        (D.singleRow (D.column (D.nonNullable D.bool)))
  res <- usePool pool $ Session.statement billId stmt
  case res of
    Right v -> pure $ QuerySuccess v
    Left err -> pure $ QueryError (T.pack $ show err)

validateDoubleEntry :: Pool -> Int64 -> IO (QueryResult Bool)
validateDoubleEntry pool entryId = do
  let stmt = preparable
        "SELECT validate_double_entry($1)"
        (E.param (E.nonNullable E.int8))
        (D.singleRow (D.column (D.nonNullable D.bool)))
  res <- usePool pool $ Session.statement entryId stmt
  case res of
    Right v -> pure $ QuerySuccess v
    Left err -> pure $ QueryError (T.pack $ show err)

calcAccountBalance :: Pool -> Int64 -> IO (QueryResult Decimal)
calcAccountBalance pool accountId = do
  let stmt = preparable
        "SELECT calc_account_balance($1)"
        (E.param (E.nonNullable E.int8))
        (D.singleRow (fmap (\n -> Decimal (realToFrac n)) (D.column (D.nonNullable D.numeric))))
  res <- usePool pool $ Session.statement accountId stmt
  case res of
    Right v -> pure $ QuerySuccess v
    Left err -> pure $ QueryError (T.pack $ show err)

getSalesReport :: Pool -> Text -> Text -> IO (QueryResult [(Text, Double)])
getSalesReport pool dateFrom dateTo = do
  let stmt = preparable
        "SELECT report_date::text, total_amount FROM get_sales_report($1, $2)"
        ((fst >$< E.param (E.nonNullable E.text)) <> (snd >$< E.param (E.nonNullable E.text)))
        (D.rowList $ (,) <$> D.column (D.nonNullable D.text) <*> D.column (D.nonNullable D.float8))
  res <- usePool pool $ Session.statement (dateFrom, dateTo) stmt
  case res of
    Right rows -> pure $ QuerySuccess rows
    Left err -> pure $ QueryError (T.pack $ show err)
