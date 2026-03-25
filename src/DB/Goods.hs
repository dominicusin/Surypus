{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards #-}

module DB.Goods
  ( listGoods,
    getGoods,
    createGoods,
    updateGoods,
    deleteGoods,
  )
where

import Data.Int (Int64)
import Data.Text (Text)
import Domain.Goods
import Domain.Types
import qualified Hasql.Decoders as D
import qualified Hasql.Encoders as E
import Hasql.Pool (Pool, use)
import qualified Hasql.Session as Session
import Hasql.Statement (Statement (..))

goodsRowDecoder :: D.Row Goods
goodsRowDecoder =
  Goods
    <$> D.column (D.nonNullable D.int8)
    <*> D.column (D.nullable D.text)
    <*> D.column (D.nonNullable D.text)
    <*> D.column (D.nullable D.text)
    <*> D.column (D.nonNullable D.int8)
    <*> D.column (D.nullable D.int8)
    <*> D.column (D.nonNullable D.int4)
    <*> D.column (D.nullable D.int8)
    <*> D.column (D.nullable D.int8)
    <*> D.column (D.nonNullable D.int4)
    <*> D.column (D.nonNullable D.float8)
    <*> D.column (D.nullable D.float8)
    <*> D.column (D.nullable D.float8)
    <*> D.column (D.nullable D.float8)

listGoods :: Pool -> Pagination -> GoodsFilter -> IO [Goods]
listGoods pool (Pagination limit offset) GoodsFilter {..} =
  use pool $
    Session.statement (limit, offset, gfName, gfBarcode, gfType, gfBrand) stmt
  where
    stmt =
      Statement
        "SELECT id, code, name, barcode, unit_id, parent_id, gtype, brand_id, category_id, status, min_stock, max_stock, weight, volume FROM goods WHERE ($3 IS NULL OR name ILIKE $3) AND ($4 IS NULL OR barcode = $4) AND ($5 IS NULL OR gtype = $5) AND ($6 IS NULL OR brand_id = $6) ORDER BY id LIMIT $1 OFFSET $2"
        ( E.param (E.nonNullable E.int4)
            <> E.param (E.nonNullable E.int4)
            <> E.param (E.nullable E.text)
            <> E.param (E.nullable E.text)
            <> E.param (E.nullable E.int4)
            <> E.param (E.nullable E.int8)
        )
        (D.rowList goodsRowDecoder)
        False

getGoods :: Pool -> Int64 -> IO (Maybe Goods)
getGoods pool gid =
  use pool $
    Session.statement gid stmt
  where
    stmt =
      Statement
        "SELECT id, code, name, barcode, unit_id, parent_id, gtype, brand_id, category_id, status, min_stock, max_stock, weight, volume FROM goods WHERE id = $1"
        (E.param (E.nonNullable E.int8))
        (D.rowMaybe goodsRowDecoder)
        False

createGoods :: Pool -> Goods -> IO Int64
createGoods pool Goods {..} =
  use pool $
    Session.statement
      ( goodsCode,
        goodsName,
        goodsBarcode,
        goodsUnitId,
        goodsParent,
        goodsType,
        goodsTaxId,
        goodsBrandId,
        goodsStatus,
        goodsMinStock,
        goodsMaxStock,
        goodsWeight,
        goodsVolume
      )
      stmt
  where
    stmt =
      Statement
        "INSERT INTO goods (code, name, barcode, unit_id, parent_id, gtype, taxcat_id, brand_id, status, min_stock, max_stock, weight, volume) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13) RETURNING id"
        ( E.param (E.nullable E.text)
            <> E.param (E.nonNullable E.text)
            <> E.param (E.nullable E.text)
            <> E.param (E.nonNullable E.int8)
            <> E.param (E.nullable E.int8)
            <> E.param (E.nonNullable E.int4)
            <> E.param (E.nullable E.int8)
            <> E.param (E.nullable E.int8)
            <> E.param (E.nonNullable E.int4)
            <> E.param (E.nonNullable E.float8)
            <> E.param (E.nullable E.float8)
            <> E.param (E.nullable E.float8)
            <> E.param (E.nullable E.float8)
        )
        (D.singleRow $ D.column (D.nonNullable D.int8))
        False

updateGoods :: Pool -> Int64 -> Goods -> IO Bool
updateGoods pool gid Goods {..} =
  use pool $
    Session.statement
      ( gid,
        goodsCode,
        goodsName,
        goodsBarcode,
        goodsUnitId,
        goodsParent,
        goodsType,
        goodsTaxId,
        goodsBrandId,
        goodsStatus,
        goodsMinStock,
        goodsMaxStock,
        goodsWeight,
        goodsVolume
      )
      stmt
  where
    stmt =
      Statement
        "UPDATE goods SET code = $2, name = $3, barcode = $4, unit_id = $5, parent_id = $6, gtype = $7, taxcat_id = $8, brand_id = $9, status = $10, min_stock = $11, max_stock = $12, weight = $13, volume = $14, updated_at = NOW() WHERE id = $1"
        ( E.param (E.nonNullable E.int8)
            <> E.param (E.nullable E.text)
            <> E.param (E.nonNullable E.text)
            <> E.param (E.nullable E.text)
            <> E.param (E.nonNullable E.int8)
            <> E.param (E.nullable E.int8)
            <> E.param (E.nonNullable E.int4)
            <> E.param (E.nullable E.int8)
            <> E.param (E.nullable E.int8)
            <> E.param (E.nonNullable E.int4)
            <> E.param (E.nonNullable E.float8)
            <> E.param (E.nullable E.float8)
            <> E.param (E.nullable E.float8)
            <> E.param (E.nullable E.float8)
        )
        D.noResult
        False

deleteGoods :: Pool -> Int64 -> IO Bool
deleteGoods pool gid =
  use pool $
    Session.statement gid stmt Data.Functor.$> True
  where
    stmt =
      Statement
        "DELETE FROM goods WHERE id = $1"
        (E.param (E.nonNullable E.int8))
        D.noResult
        False
