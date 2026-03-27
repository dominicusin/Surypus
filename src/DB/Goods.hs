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
import Hasql.Statement (unpreparable)

goodsRowDecoder :: D.Row Goods
goodsRowDecoder =
  Goods
    <$> (Just <$> D.column (D.nonNullable D.int8))
    <*> D.column (D.nullable D.text)
    <*> D.column (D.nonNullable D.text)
    <*> D.column (D.nullable D.text)
    <*> D.column (D.nonNullable D.int8)
    <*> D.column (D.nullable D.int8)
    <*> (fromIntegral <$> D.column (D.nonNullable D.int4))
    <*> D.column (D.nullable D.int8)
    <*> D.column (D.nullable D.int8)
    <*> (fromIntegral <$> D.column (D.nonNullable D.int4))
    <*> (realToFrac <$> D.column (D.nonNullable D.float8))
    <*> (fmap realToFrac <$> D.column (D.nullable D.float8))
    <*> (fmap realToFrac <$> D.column (D.nullable D.float8))
    <*> (fmap realToFrac <$> D.column (D.nullable D.float8))

listGoods :: Pool -> Pagination -> GoodsFilter -> IO [Goods]
listGoods pool (Pagination limit' offset') GoodsFilter {..} = do
  result <- use pool $ Session.statement (fromIntegral limit' :: Int, fromIntegral offset' :: Int, gfName, gfBarcode, fmap fromIntegral gfType, gfBrand) stmt
  case result of
    Right x -> pure x
    Left _ -> pure []
  where
    stmt =
      unpreparable
        "SELECT id, code, name, barcode, unit_id, parent_id, gtype, brand_id, category_id, status, min_stock, max_stock, weight, volume FROM goods WHERE ($3 IS NULL OR name ILIKE $3) AND ($4 IS NULL OR barcode = $4) AND ($5 IS NULL OR gtype = $5) AND ($6 IS NULL OR brand_id = $6) ORDER BY id LIMIT $1 OFFSET $2"
        ( E.param (E.nonNullable E.int4)
            <> E.param (E.nonNullable E.int4)
            <> E.param (E.nullable E.text)
            <> E.param (E.nullable E.text)
            <> E.param (E.nullable E.int4)
            <> E.param (E.nullable E.int8)
        )
        (D.rowList goodsRowDecoder)

getGoods :: Pool -> Int64 -> IO (Maybe Goods)
getGoods pool gid = do
  result <- use pool $ Session.statement gid stmt
  case result of
    Right x -> pure x
    Left _ -> pure Nothing
  where
    stmt =
      unpreparable
        "SELECT id, code, name, barcode, unit_id, parent_id, gtype, brand_id, category_id, status, min_stock, max_stock, weight, volume FROM goods WHERE id = $1"
        (E.param (E.nonNullable E.int8))
        (D.rowMaybe goodsRowDecoder)

createGoods :: Pool -> Goods -> IO Int64
createGoods pool Goods {..} = do
  result <- use pool $ Session.statement params stmt
  case result of
    Right x -> pure x
    Left _ -> pure 0
  where
    params =
      ( goodsCode,
        goodsName,
        goodsBarcode,
        goodsUnitId,
        goodsParent,
        fromIntegral goodsType :: Int,
        goodsBrandId,
        fromIntegral goodsStatus :: Int,
        goodsMinStock
      )
    stmt =
      unpreparable
        "INSERT INTO goods (code, name, barcode, unit_id, parent_id, gtype, brand_id, status, min_stock) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9) RETURNING id"
        ( E.param (E.nullable E.text)
            <> E.param (E.nonNullable E.text)
            <> E.param (E.nullable E.text)
            <> E.param (E.nonNullable E.int8)
            <> E.param (E.nullable E.int8)
            <> E.param (E.nonNullable E.int4)
            <> E.param (E.nullable E.int8)
            <> E.param (E.nonNullable E.int4)
            <> E.param (E.nonNullable E.float8)
        )
        (D.singleRow $ D.column (D.nonNullable D.int8))

updateGoods :: Pool -> Int64 -> Goods -> IO (Maybe Goods)
updateGoods pool gid Goods {..} = do
  result <- use pool $ Session.statement params stmt
  case result of
    Right x -> pure x
    Left _ -> pure Nothing
  where
    params =
      ( gid,
        goodsCode,
        goodsName,
        goodsBarcode,
        goodsUnitId,
        goodsParent,
        fromIntegral goodsType :: Int,
        goodsBrandId,
        fromIntegral goodsStatus :: Int,
        goodsMinStock
      )
    stmt =
      unpreparable
        "UPDATE goods SET code = $2, name = $3, barcode = $4, unit_id = $5, parent_id = $6, gtype = $7, brand_id = $8, status = $9, min_stock = $10 WHERE id = $1 RETURNING id, code, name, barcode, unit_id, parent_id, gtype, brand_id, category_id, status, min_stock, max_stock, weight, volume"
        ( E.param (E.nonNullable E.int8)
            <> E.param (E.nullable E.text)
            <> E.param (E.nonNullable E.text)
            <> E.param (E.nullable E.text)
            <> E.param (E.nonNullable E.int8)
            <> E.param (E.nullable E.int8)
            <> E.param (E.nonNullable E.int4)
            <> E.param (E.nullable E.int8)
            <> E.param (E.nonNullable E.int4)
            <> E.param (E.nonNullable E.float8)
        )
        (D.rowMaybe goodsRowDecoder)

deleteGoods :: Pool -> Int64 -> IO Bool
deleteGoods pool gid = do
  result <- use pool $ Session.statement gid stmt
  case result of
    Right _ -> pure True
    Left _ -> pure False
  where
    stmt =
      unpreparable
        "DELETE FROM goods WHERE id = $1"
        (E.param (E.nonNullable E.int8))
        D.noResult
