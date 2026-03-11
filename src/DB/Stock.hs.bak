{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards #-}

module DB.Stock
  ( listStock
  , getStock
  , reserveStock
  ) where

import Data.Int (Int64)
import Data.Text (Text)
import Hasql.Pool (Pool, use)
import Hasql.Statement (Statement (..))
import qualified Hasql.Encoders as E
import qualified Hasql.Decoders as D
import qualified Hasql.Session as Session
import Domain.Stock
import Domain.Types

stockRowDecoder :: D.Row Stock
stockRowDecoder =
  Stock
    <$> D.column (D.nonNullable D.int8)
    <*> D.column (D.nonNullable D.int8)
    <*> D.column (D.nonNullable D.int8)
    <*> D.column (D.nonNullable D.float8)
    <*> D.column (D.nonNullable D.float8)
    <*> D.column (D.nonNullable D.float8)
    <*> D.column (D.nonNullable D.float8)
    <*> D.column (D.nullable D.text)

listStock :: Pool -> Pagination -> StockFilter -> IO [Stock]
listStock pool (Pagination limit offset) StockFilter{..} = use pool $
  Session.statement (limit, offset, sfGoodsId, sfLocationId) stmt
  where
    stmt = Statement
      "SELECT s.id, s.goods_id, s.location_id, s.quantity, s.reserved_qty, s.cost, s.price, l.serial FROM stock s LEFT JOIN lot l ON l.id = s.lot_id WHERE ($3 IS NULL OR s.goods_id = $3) AND ($4 IS NULL OR s.location_id = $4) ORDER BY s.id LIMIT $1 OFFSET $2"
      (  E.param (E.nonNullable E.int4)
      <> E.param (E.nonNullable E.int4)
      <> E.param (E.nullable E.int8)
      <> E.param (E.nullable E.int8)
      )
      (D.rowList stockRowDecoder)
      False

getStock :: Pool -> Int64 -> Int64 -> IO (Maybe Stock)
getStock pool goodsId locId = use pool $
  Session.statement (goodsId, locId) stmt
  where
    stmt = Statement
      "SELECT s.id, s.goods_id, s.location_id, s.quantity, s.reserved_qty, s.cost, s.price, l.serial FROM stock s LEFT JOIN lot l ON l.id = s.lot_id WHERE s.goods_id = $1 AND s.location_id = $2"
      (  E.param (E.nonNullable E.int8)
      <> E.param (E.nonNullable E.int8)
      )
      (D.rowMaybe stockRowDecoder)
      False

reserveStock :: Pool -> Int64 -> Int64 -> Double -> IO (Maybe Stock)
reserveStock pool goodsId locId qty
  | qty <= 0 = pure Nothing
  | otherwise = use pool $
      Session.statement (goodsId, locId, qty) stmt
  where
    stmt = Statement
      "UPDATE stock SET reserved_qty = reserved_qty + $3 WHERE goods_id = $1 AND location_id = $2 AND quantity >= reserved_qty + $3 RETURNING id, goods_id, location_id, quantity, reserved_qty, cost, price, NULL"
      (  E.param (E.nonNullable E.int8)
      <> E.param (E.nonNullable E.int8)
      <> E.param (E.nonNullable E.float8)
      )
      (D.rowMaybe $ Stock
        <$> D.column (D.nonNullable D.int8)
        <*> D.column (D.nonNullable D.int8)
        <*> D.column (D.nonNullable D.int8)
        <*> D.column (D.nonNullable D.float8)
        <*> D.column (D.nonNullable D.float8)
        <*> D.column (D.nonNullable D.float8)
        <*> D.column (D.nonNullable D.float8)
        <*> pure Nothing
      )
      False
