{-# LANGUAGE OverloadedStrings #-}

-- ============================================================================
-- DAL.Procedures - database procedure shims and placeholders
-- ============================================================================
module DAL.Procedures where

import DAL.Types (FifoLot (..), LotBounds (..), LowStockItem (..), QueryResult (..))
import Data.Decimal (Decimal, DecimalRaw (..))
import Data.Int (Int64)

-- Validation wrappers and simple placeholder implementations
-- NOTE: These procedures are designed as placeholders and return deterministic
-- results until a real database backend is wired in. They are used by the
-- higher layers for type-checking and integration testing.
calcVat :: () -> Double -> Double -> IO (QueryResult Double)
calcVat _ amount rate = pure $ QuerySuccess (amount * rate / 100)

calcVatInclusive :: () -> Double -> Double -> IO (QueryResult Double)
calcVatInclusive _ inclusive rate = pure $ QuerySuccess (inclusive / (1 + rate / 100))

calcPriceWithoutVat :: () -> Double -> Double -> IO (QueryResult Double)
calcPriceWithoutVat _ inclusive rate = pure $ QuerySuccess (inclusive / (1 + rate / 100))

calcStockBalance :: () -> Int64 -> Int64 -> Maybe Double -> IO (QueryResult Decimal)
calcStockBalance _ _ _ _ = pure $ QuerySuccess (Decimal 0 0)

calcGoodsAvgCost :: () -> Int64 -> Int64 -> IO (QueryResult Decimal)
calcGoodsAvgCost _ _ _ = pure $ QuerySuccess (Decimal 0 0)

getLowStockItems :: () -> Maybe Double -> IO (QueryResult [LowStockItem])
getLowStockItems _ _ = pure $ QuerySuccess []

getFifoLots :: () -> Int64 -> Int64 -> Double -> IO (QueryResult [FifoLot])
getFifoLots _ _ _ _ = pure $ QuerySuccess []

getLotBounds :: () -> Int64 -> Int64 -> IO (QueryResult [LotBounds])
getLotBounds _ _ _ = pure $ QuerySuccess []

checkReorderNeeded :: () -> Int64 -> Int64 -> IO (QueryResult Bool)
checkReorderNeeded _ _ _ = pure $ QuerySuccess False

fifoSelectLots :: () -> Int64 -> Int64 -> Double -> IO (QueryResult [FifoLot])
fifoSelectLots _ _ _ _ = pure $ QuerySuccess []
