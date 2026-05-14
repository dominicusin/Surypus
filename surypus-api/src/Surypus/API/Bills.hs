{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE OverloadedStrings #-}

module Surypus.API.Bills
  ( listBills,
    createBill,
    getBill,
    updateBill,
    deleteBill
  )
where

import DAL.Types (Bill (..), BillInput (..), QueryResult (..))
import Data.Functor.Contravariant ((>$<))
import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import Data.Time (Day)
import qualified Hasql.Decoders as D
import qualified Hasql.Encoders as E
import Hasql.Pool (Pool, use)
import qualified Hasql.Session as Session
import Hasql.Statement (Statement (..))

listBills :: Pool -> Maybe Text -> Maybe Text -> Maybe Int -> Maybe Int -> Maybe Int -> Maybe Int -> IO (QueryResult [Bill])
listBills pool _ _ _ _ _ _ = do
  result <- use pool $ Session.statement () selectBillsStmt
  return $ case result of
    Left err -> QueryError (T.pack $ show err)
    Right bills -> QuerySuccess bills

selectBillsStmt :: Statement () [Bill]
selectBillsStmt = Statement sql encoder decoder True
  where
    sql = "SELECT id, number, status, amount, created_at FROM bills ORDER BY id LIMIT 50"
    encoder = E.noParams
    decoder = D.rowList billDecoder

createBill :: Pool -> BillInput -> IO (QueryResult Bill)
createBill pool input = do
  result <- use pool $ Session.statement (biCode input, biType input, biStatus input, biDate input) insertBillStmt
  return $ case result of
    Left err -> QueryError (T.pack $ show err)
    Right bill -> QuerySuccess bill

insertBillStmt :: Statement (Maybe Text, Int, Int, Day) Bill
insertBillStmt = Statement sql encoder decoder True
  where
    sql = "INSERT INTO bills (number, status, amount, created_at) VALUES ($1, $2, $3, $4) RETURNING id, number, status, amount, created_at"
    encoder =
      ((\(number, _, _, _) -> number) >$< E.param (E.nullable E.text))
        <> ((\(_, status, _, _) -> status) >$< E.param (E.nonNullable E.int4))
        <> ((\(_, _, amount, _) -> amount) >$< E.param (E.nonNullable E.float8))
        <> ((\(_, _, _, date) -> date) >$< E.param (E.nonNullable E.date))
    decoder = D.singleRow billDecoder

getBill :: Pool -> Int64 -> IO (QueryResult Bill)
getBill pool bid = do
  result <- use pool $ Session.statement bid selectBillStmt
  return $ case result of
    Left err -> QueryError (T.pack $ show err)
    Right bill -> QuerySuccess bill

selectBillStmt :: Statement Int64 Bill
selectBillStmt = Statement sql encoder decoder True
  where
    sql = "SELECT id, number, status, amount, created_at FROM bills WHERE id = $1"
    encoder = ((\(bid) -> bid) >$< E.param (E.nonNullable E.int8))
    decoder = D.singleRow billDecoder

updateBill :: Pool -> Int64 -> BillInput -> IO (QueryResult Bill)
updateBill pool bid input = do
  result <- use pool $ Session.statement (biCode input, biType input, biStatus input, biDate input, bid) updateBillStmt
  return $ case result of
    Left err -> QueryError (T.pack $ show err)
    Right bill -> QuerySuccess bill

updateBillStmt :: Statement (Maybe Text, Int, Int, Day, Int64) Bill
updateBillStmt = Statement sql encoder decoder True
  where
    sql = "UPDATE bills SET number = $1, status = $2, amount = $3, created_at = $4 WHERE id = $5 RETURNING id, number, status, amount, created_at"
    encoder =
      ((\(number, _, _, _, _) -> number) >$< E.param (E.nullable E.text))
        <> ((\(_, status, _, _, _) -> status) >$< E.param (E.nonNullable E.int4))
        <> ((\(_, _, amount, _, _) -> amount) >$< E.param (E.nonNullable E.float8))
        <> ((\(_, _, _, date, _) -> date) >$< E.param (E.nonNullable E.date))
        <> ((\(_, _, _, _, bid) -> bid) >$< E.param (E.nonNullable E.int8))
    decoder = D.singleRow billDecoder

deleteBill :: Pool -> Int64 -> IO (QueryResult ())
deleteBill pool bid = do
  result <- use pool $ Session.statement bid deleteBillStmt
  return $ case result of
    Left err -> QueryError (T.pack $ show err)
    Right () -> QuerySuccess ()

deleteBillStmt :: Statement Int64 ()
deleteBillStmt = Statement sql encoder decoder True
  where
    sql = "DELETE FROM bills WHERE id = $1"
    encoder = ((\(gid) -> gid) >$< E.param (E.nonNullable E.int8))
    decoder = D.noResult

billDecoder :: D.Row Bill
billDecoder =
  Bill
    <$> D.column (D.nonNullable D.int8)
    <*> D.column (D.nullable D.text)  -- billNumber (already Maybe Text)
    <*> fromIntegral <$> D.column (D.nonNullable D.int4)  -- billStatus
    <*> D.column (D.nonNullable D.float8)  -- billAmount
    <*> pure []  -- billLines
    <*> D.column (D.nonNullable D.timestamptz)  -- billCreatedAt
    <*> D.column (D.nullable D.timestamptz)  -- billUpdatedAt
    <*> D.column (D.nullable D.int8)  -- billPersonId
    <*> D.column (D.nullable D.int8)  -- billLocationId