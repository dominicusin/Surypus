{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE OverloadedStrings #-}

module Surypus.API.Goods
  ( listGoods,
    createGoods,
    getGoods,
    updateGoods,
    deleteGoods,
    searchGoods,
  )
where

import DAL.Types (Goods (..), GoodsInput (..), QueryResult (..))
import Data.Functor.Contravariant ((>$<))
import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import qualified Hasql.Decoders as D
import qualified Hasql.Encoders as E
import Hasql.Pool (Pool, use)
import qualified Hasql.Session as Session
import Hasql.Statement (Statement (..))

listGoods :: Pool -> Maybe Text -> Maybe Text -> Maybe Text -> Maybe Int -> IO (QueryResult [Goods])
listGoods pool _ _ _ _ = do
  result <- use pool $ Session.statement () selectGoodsListStmt
  return $ case result of
    Left err -> QueryError (T.pack $ show err)
    Right goods -> QuerySuccess goods

createGoods :: Pool -> GoodsInput -> IO (QueryResult Goods)
createGoods pool input = do
  result <- use pool $ Session.statement (giName input, giCode input, giBarcode input, giUnitId input, giParentId input) insertGoodsStmt
  return $ case result of
    Left err -> QueryError (T.pack $ show err)
    Right g -> QuerySuccess g

getGoods :: Pool -> Int64 -> IO (QueryResult Goods)
getGoods pool gid = do
  result <- use pool $ Session.statement gid selectGoodsStmt
  return $ case result of
    Left err -> QueryError (T.pack $ show err)
    Right g -> QuerySuccess g

updateGoods :: Pool -> Int64 -> GoodsInput -> IO (QueryResult Goods)
updateGoods pool gid input = do
  result <- use pool $ Session.statement (input, gid) updateGoodsStmt
  return $ case result of
    Left err -> QueryError (T.pack $ show err)
    Right g -> QuerySuccess g

deleteGoods :: Pool -> Int64 -> IO (QueryResult ())
deleteGoods pool gid = do
  result <- use pool $ Session.statement gid deleteGoodsStmt
  return $ case result of
    Left err -> QueryError (T.pack $ show err)
    Right () -> QuerySuccess ()

searchGoods :: Pool -> Text -> IO (QueryResult [Goods])
searchGoods pool query = do
  result <- use pool $ Session.statement (T.append "%" (T.append query "%")) searchGoodsStmt
  return $ case result of
    Left err -> QueryError (T.pack $ show err)
    Right goods -> QuerySuccess goods

selectGoodsStmt :: Statement Int64 Goods
selectGoodsStmt = Statement sql encoder decoder True
  where
    sql = "SELECT id, name, code, barcode, unit_id, parent_id FROM goods WHERE id = $1"
    encoder = ((\(gid) -> gid) >$< E.param (E.nonNullable E.int8))
    decoder = D.singleRow goodsDecoder

selectGoodsListStmt :: Statement () [Goods]
selectGoodsListStmt = Statement sql encoder decoder True
  where
    sql = "SELECT id, name, code, barcode, unit_id, parent_id FROM goods ORDER BY id LIMIT 50"
    encoder = E.noParams
    decoder = D.rowList goodsDecoder

insertGoodsStmt :: Statement (Text, Maybe Text, Maybe Text, Int64, Maybe Int64) Goods
insertGoodsStmt = Statement sql encoder decoder True
  where
    sql = "INSERT INTO goods (name, code, barcode, unit_id, parent_id) VALUES ($1, $2, $3, $4, $5) RETURNING id, name, code, barcode, unit_id, parent_id"
    encoder =
      ((\(name, _, _, _, _) -> name) >$< E.param (E.nonNullable E.text))
        <> ((\(_, code, _, _, _) -> code) >$< E.param (E.nullable E.text))
        <> ((\(_, _, barcode, _, _) -> barcode) >$< E.param (E.nullable E.text))
        <> ((\(_, _, _, unit_id, _) -> unit_id) >$< E.param (E.nonNullable E.int8))
        <> ((\(_, _, _, _, parent_id) -> parent_id) >$< E.param (E.nullable E.int8))
    decoder = D.singleRow goodsDecoder

updateGoodsStmt :: Statement (GoodsInput, Int64) Goods
updateGoodsStmt = Statement sql encoder decoder True
  where
    sql = "UPDATE goods SET name = $1, code = $2, barcode = $3, unit_id = $4, parent_id = $5 WHERE id = $6 RETURNING id, name, code, barcode, unit_id, parent_id"
    encoder =
      ((\(gi, _) -> giName gi) >$< E.param (E.nonNullable E.text))
        <> ((\(gi, _) -> giCode gi) >$< E.param (E.nullable E.text))
        <> ((\(gi, _) -> giBarcode gi) >$< E.param (E.nullable E.text))
        <> ((\(gi, _) -> giUnitId gi) >$< E.param (E.nonNullable E.int8))
        <> ((\(gi, _) -> giParentId gi) >$< E.param (E.nullable E.int8))
        <> ((\(_, gid) -> gid) >$< E.param (E.nonNullable E.int8))
    decoder = D.singleRow goodsDecoder

deleteGoodsStmt :: Statement Int64 ()
deleteGoodsStmt = Statement sql encoder decoder True
  where
    sql = "DELETE FROM goods WHERE id = $1"
    encoder = ((\(gid) -> gid) >$< E.param (E.nonNullable E.int8))
    decoder = D.noResult

searchGoodsStmt :: Statement Text [Goods]
searchGoodsStmt = Statement sql encoder decoder True
  where
    sql = "SELECT id, name, code, barcode, unit_id, parent_id FROM goods WHERE name ILIKE $1 OR code ILIKE $1 LIMIT 50"
    encoder = ((\(query) -> query) >$< E.param (E.nonNullable E.text))
    decoder = D.rowList goodsDecoder

goodsDecoder :: D.Row Goods
goodsDecoder =
  Goods
    <$> D.column (D.nonNullable D.int8)
    <*> D.column (D.nullable D.text)
    <*> D.column (D.nonNullable D.text)
    <*> D.column (D.nullable D.text)
    <*> D.column (D.nonNullable D.int8)
    <*> D.column (D.nullable D.int8)
