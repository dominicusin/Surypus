{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards #-}

module DB.Stock
  ( listStock,
    getStock,
    reserveStock,
  )
where

import Data.Int (Int32, Int64)
import Data.Text (Text)
import qualified Data.Text as T
import Domain.Stock
import Domain.Types
import qualified Hasql.Decoders as D
import qualified Hasql.Encoders as E
import Hasql.Pool (Pool, use)
import qualified Hasql.Session as Session
import Hasql.Statement (Statement)

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

-- | List stock with pagination and filtering
listStock :: Pool -> Pagination -> StockFilter -> IO [Stock]
listStock pool (Pagination limit' offset') StockFilter {..} = do
  let stmt =
        Statement
          "SELECT s.id, s.goods_id, s.location_id, s.quantity, s.reserved_qty, s.cost, s.price, l.serial FROM stock s LEFT JOIN lot l ON l.id = s.lot_id WHERE ($3 IS NULL OR s.goods_id = $3) AND ($4 IS NULL OR s.location_id = $4) ORDER BY s.id LIMIT $1 OFFSET $2"
          ( E.param (E.nonNullable E.int4)
              <> E.param (E.nonNullable E.int4)
              <> E.param (E.nullable E.int8)
              <> E.param (E.nullable E.int8)
          )
          (D.rowList stockRowDecoder)
  result <- use pool $ Session.statement (fromIntegral limit' :: Int32, fromIntegral offset' :: Int32, sfGoodsId, sfLocationId) stmt
  case result of
    Right stocks -> pure stocks
    Left _ -> pure []

-- | Get stock by goods ID and location ID
getStock :: Pool -> Int64 -> Int64 -> IO (Maybe Stock)
getStock pool goodsId locId = do
  let stmt =
        Statement
          "SELECT s.id, s.goods_id, s.location_id, s.quantity, s.reserved_qty, s.cost, s.price, l.serial FROM stock s LEFT JOIN lot l ON l.id = s.lot_id WHERE s.goods_id = $1 AND s.location_id = $2"
          ( E.param (E.nonNullable E.int8)
              <> E.param (E.nonNullable E.int8)
          )
          (D.rowMaybe stockRowDecoder)
  result <- use pool $ Session.statement (goodsId, locId) stmt
  case result of
    Right stock -> pure stock
    Left _ -> pure Nothing

-- | Reserve stock quantity
reserveStock :: Pool -> Int64 -> Int64 -> Double -> IO (Maybe Stock)
reserveStock pool goodsId locId qty
  | qty <= 0 = pure Nothing
  | otherwise = do
      let stmt =
            Statement
              "UPDATE stock SET reserved_qty = reserved_qty + $3 WHERE goods_id = $1 AND location_id = $2 AND quantity >= reserved_qty + $3 RETURNING id, goods_id, location_id, quantity, reserved_qty, cost, price, NULL"
              ( E.param (E.nonNullable E.int8)
                  <> E.param (E.nonNullable E.int8)
                  <> E.param (E.nonNullable E.float8)
              )
              ( D.rowMaybe $
                  Stock
                    <$> D.column (D.nonNullable D.int8)
                    <*> D.column (D.nonNullable D.int8)
                    <*> D.column (D.nonNullable D.int8)
                    <*> D.column (D.nonNullable D.float8)
                    <*> D.column (D.nonNullable D.float8)
                    <*> D.column (D.nonNullable D.float8)
                    <*> D.column (D.nonNullable D.float8)
                    <*> pure Nothing
              )
      result <- use pool $ Session.statement (goodsId, locId, qty) stmt
      case result of
        Right stock -> pure stock
        Left _ -> pure Nothing
