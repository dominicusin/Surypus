{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE OverloadedStrings #-}

module Surypus.API.Bills
  ( listBills,
    createBill,
    getBill,
    updateBill,
    deleteBill,
  )
where

import DAL.Types (Bill (..), BillInput (..), Decimal (..), QueryResult (..))
import Data.Functor.Contravariant ((>$<))
import Data.Int (Int32, Int64)
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
    sql = "SELECT id, code, type, status, date FROM bills ORDER BY id LIMIT 50"
    encoder = E.noParams
    decoder = D.rowList billDecoder

createBill :: Pool -> BillInput -> IO (QueryResult Bill)
createBill pool input = do
  result <- use pool $ Session.statement (biCode input, fromIntegral (biType input), fromIntegral (biStatus input), biDate input) insertBillStmt
  return $ case result of
    Left err -> QueryError (T.pack $ show err)
    Right bill -> QuerySuccess bill

insertBillStmt :: Statement (Maybe Text, Int32, Int32, Day) Bill
insertBillStmt = Statement sql encoder decoder True
  where
    sql = "INSERT INTO bills (code, type, status, date) VALUES ($1, $2, $3, $4) RETURNING id, code, type, status, date"
    encoder =
      ((\(code, _, _, _) -> code) >$< E.param (E.nullable E.text))
        <> ((\(_, type', _, _) -> type') >$< E.param (E.nonNullable E.int4))
        <> ((\(_, _, status, _) -> status) >$< E.param (E.nonNullable E.int4))
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
    sql = "SELECT id, code, type, status, date FROM bills WHERE id = $1"
    encoder = ((\(bid) -> bid) >$< E.param (E.nonNullable E.int8))
    decoder = D.singleRow billDecoder

updateBill :: Pool -> Int64 -> BillInput -> IO (QueryResult Bill)
updateBill pool bid input = do
  result <- use pool $ Session.statement (biCode input, fromIntegral (biType input), fromIntegral (biStatus input), biDate input, bid) updateBillStmt
  return $ case result of
    Left err -> QueryError (T.pack $ show err)
    Right bill -> QuerySuccess bill

updateBillStmt :: Statement (Maybe Text, Int, Int, Day, Int64) Bill
updateBillStmt = Statement sql encoder decoder True
  where
    sql = "UPDATE bills SET code = $1, type = $2, status = $3, date = $4 WHERE id = $5 RETURNING id, code, type, status, date"
    encoder =
      ((\(code, _, _, _, _) -> code) >$< E.param (E.nullable E.text))
        <> ((\(_, type', _, _, _) -> fromIntegral type') >$< E.param (E.nonNullable E.int4))
        <> ((\(_, _, status, _, _) -> fromIntegral status) >$< E.param (E.nonNullable E.int4))
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
    <*> D.column (D.nullable D.text)
    <*> (fromIntegral <$> D.column (D.nonNullable D.int2))
    <*> (fromIntegral <$> D.column (D.nonNullable D.int2))
    <*> D.column (D.nonNullable D.date)
    <*> D.column (D.nullable D.int8)
    <*> D.column (D.nullable D.int8)
    <*> (DAL.Types.Decimal . round <$> D.column (D.nonNullable D.numeric))
    <*> (DAL.Types.Decimal . round <$> D.column (D.nonNullable D.numeric))
    <*> (DAL.Types.Decimal . round <$> D.column (D.nonNullable D.numeric))
