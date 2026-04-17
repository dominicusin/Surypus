{-# LANGUAGE OverloadedStrings #-}

module DAL.Procedures.Generated where

import DAL.Types (FifoLot (..), LotBounds (..), LowStockItem (..), QueryResult (..))
import qualified DAL.Types as DT
import Data.Decimal (Decimal)
import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import Data.Time (Day)
import qualified Hasql.Decoders as D
import qualified Hasql.Decoders as DD
import qualified Hasql.Encoders as E
import Hasql.Pool (Pool, use)
import qualified Hasql.Session as Session

-- Decoders
lowStockItemDecoder :: D.Row LowStockItem
lowStockItemDecoder =
  LowStockItem
    <$> D.column (D.nonNullable D.int8)
    <*> D.column (D.nonNullable D.text)
    <*> (Decimal . round <$> D.column (D.nonNullable D.numeric))
    <*> (Decimal . round <$> D.column (D.nonNullable D.numeric))

fifoLotDecoder :: D.Row FifoLot
fifoLotDecoder =
  FifoLot
    <$> D.column (D.nonNullable D.int8)
    <*> D.column (D.nonNullable D.date)
    <*> (Decimal . round <$> D.column (D.nonNullable D.numeric))
    <*> (Decimal . round <$> D.column (D.nonNullable D.numeric))

l otBoundsDecoder :: D.Row LotBounds
lotBoundsDecoder :: D.Row LotBounds
lotBoundsDecoder =
  LotBounds
    <$> D.column (D.nonNullable D.date)
    <*> D.column (D.nonNullable D.date)
    <*> (Decimal . round <$> D.column (D.nonNullable D.numeric))

-- Primary wrappers (skeleton) – real implementations to be filled later
getLowStockItems :: Pool -> Maybe Double -> IO (QueryResult [LowStockItem])
getLowStockItems pool mThreshold = do
  let stmt =
        preparable
          "SELECT goods_id, name, current_qty, reorder_point FROM get_low_stock_items($1)"
          (E.param (E.nullable E.float8))
          (D.rowList lowStockItemDecoder)
  res <- use pool $ Session.statement mThreshold stmt
  case res of
    Right items -> pure $ QuerySuccess items
    Left err -> pure $ QueryError (T.pack $ show err)

getFifoLots :: Pool -> Int64 -> Int64 -> Double -> IO (QueryResult [FifoLot])
getFifoLots pool goodsId locationId qty = do
  let stmt =
        preparable
          "SELECT lot_id, lot_date, qty_used, cost FROM fifo_select_lots($1, $2, $3)"
          ( (\(g, l, q) -> g)
              >$< E.param (E.nonNullable E.int8)
                <> (\(g, l, q) -> l)
              >$< E.param (E.nonNullable E.int8)
                <> (\(g, l, q) -> q)
              >$< E.param (E.nonNullable E.float8)
          )
          (D.rowList fifoLotDecoder)
  res <- use pool $ Session.statement (goodsId, locationId, qty) stmt
  case res of
    Right lots -> pure $ QuerySuccess lots
    Left err -> pure $ QueryError (T.pack $ show err)

getLotBounds :: Pool -> Int64 -> Int64 -> IO (QueryResult [LotBounds])
getLotBounds pool goodsId locationId = do
  let stmt =
        preparable
          "SELECT min_date, max_date, total_qty FROM get_lot_bounds($1, $2)"
          ( (fst >$< E.param (E.nonNullable E.int8))
              <> (snd >$< E.param (E.nonNullable E.int8))
          )
          (D.rowList lotBoundsDecoder)
  res <- use pool $ Session.statement (goodsId, locationId) stmt
  case res of
    Right bounds -> pure $ QuerySuccess bounds
    Left err -> pure $ QueryError (T.pack $ show err)
