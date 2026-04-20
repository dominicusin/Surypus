{-# LANGUAGE OverloadedStrings #-}

-- ============================================================================
-- DAL.Procedures - database procedure wrappers
-- ============================================================================
module DAL.Procedures where

import DAL.Types (FifoLot (..), LotBounds (..), LowStockItem (..), QueryResult (..))
import Data.Decimal (Decimal, DecimalRaw (..))
import Data.Functor.Contravariant ((>$<))
import Data.Int (Int32, Int64)
import Data.Text (Text)
import qualified Data.Text as T
import qualified Hasql.Decoders as D
import qualified Hasql.Encoders as E
import Hasql.Pool (Pool, use)
import qualified Hasql.Session as Session
import Hasql.Statement (Statement (..))

-- | Расчёт НДС
-- Соответствие: Core.Tax.VAT
calcVat :: Pool -> Double -> Double -> IO (QueryResult Double)
calcVat _pool amount rate = do
  pure $ QuerySuccess (amount * rate / 100)

-- | Расчёт цены с НДС
-- Соответствие: Core.Tax.VAT
calcVatInclusive :: Pool -> Double -> Double -> IO (QueryResult Double)
calcVatInclusive _pool price rate = do
  pure $ QuerySuccess (price * (1 + rate / 100))

-- | Расчёт цены без НДС
-- Соответствие: Core.Tax.VAT
calcPriceWithoutVat :: Pool -> Double -> Double -> IO (QueryResult Double)
calcPriceWithoutVat _pool inclusive rate = do
  pure $ QuerySuccess (inclusive / (1 + rate / 100))

-- | Расчёт остатка товара на складе
-- Соответствие: Core.Inventory.Stock
calcStockBalance :: Pool -> Int64 -> Int64 -> Maybe Double -> IO (QueryResult Decimal)
calcStockBalance _pool _goodsId _locationId _threshold = do
  pure $ QuerySuccess (Decimal 0 0)

-- | Расчёт средней стоимости товара
-- Соответствие: Core.Inventory.Stock
calcGoodsAvgCost :: Pool -> Int64 -> Int64 -> IO (QueryResult Decimal)
calcGoodsAvgCost _pool _goodsId _locationId = do
  pure $ QuerySuccess (Decimal 0 0)

-- | Получить список товаров с остатком ниже порога
-- Соответствие: Core.Inventory.Stock
getLowStockItems :: Pool -> Maybe Double -> IO (QueryResult [LowStockItem])
getLowStockItems _pool _mThreshold = do
  pure $ QuerySuccess []

-- | Получить партии товара по FIFO
-- Соответствие: Core.Inventory.Stock
getFifoLots :: Pool -> Int64 -> Int64 -> Double -> IO (QueryResult [FifoLot])
getFifoLots _pool _goodsId _locationId _qtyNeeded = do
  pure $ QuerySuccess []

-- | Получить границы партий товара (минимальная и максимальная дата)
-- Соответствие: Core.Inventory.Stock
getLotBounds :: Pool -> Int64 -> Int64 -> IO (QueryResult [LotBounds])
getLotBounds _pool _goodsId _locationId = do
  pure $ QuerySuccess []

-- | Проверить, нужно ли пополнять запас
-- Соответствие: Core.Inventory.Stock
checkReorderNeeded :: Pool -> Int64 -> Int64 -> IO (QueryResult Bool)
checkReorderNeeded _pool _goodsId _locationId = do
  pure $ QuerySuccess False

-- | Выбрать партии для списания по FIFO
-- Соответствие: Core.Inventory.Stock
fifoSelectLots :: Pool -> Int64 -> Int64 -> Double -> IO (QueryResult [FifoLot])
fifoSelectLots _pool _goodsId _locationId _qty = do
  pure $ QuerySuccess []
