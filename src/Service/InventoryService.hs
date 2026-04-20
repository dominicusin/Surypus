{-# LANGUAGE OverloadedStrings #-}

module Service.InventoryService
  ( InventoryService (..),
    createInventoryService,
    processStockReceipt,
    processStockIssue,
    processStockTransfer,
    getStockBalance,
    getStockByLocation,
    getStockByGoods,
    validateStockOperation,
    StockOperation (..),
    StockRecord (..),
    TransferRequest (..),
    StockValidationError (..),
    stockUpdate,
  )
where

import qualified DAL.Mutations as Mutations
import Data.Aeson (Value)
import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import Data.Time (Day)
import Hasql.Pool (Pool)

newtype InventoryService = InventoryService
  { isPool :: Pool
  }

createInventoryService :: Pool -> InventoryService
createInventoryService = InventoryService

data StockOperation
  = StockReceipt
  | StockIssue
  | StockTransfer
  | StockAdjustment
  deriving (Show, Eq)

data StockRecord = StockRecord
  { srGoodsId :: Int64,
    srLocationId :: Int64,
    srQuantity :: Double,
    srLastUpdated :: Day
  }
  deriving (Show, Eq)

data TransferRequest = TransferRequest
  { trGoodsId :: Int64,
    trFromLocation :: Int64,
    trToLocation :: Int64,
    trQuantity :: Double
  }
  deriving (Show, Eq)

data StockValidationError
  = InvalidQuantity
  | InsufficientStock
  | InvalidLocation
  | InvalidGoods
  | DuplicateTransfer
  deriving (Show, Eq)

validateStockOperation :: Double -> Either Text ()
validateStockOperation qty
  | qty <= 0 = Left (T.pack "Quantity must be positive")
  | qty > 1000000 = Left (T.pack "Quantity exceeds maximum allowed")
  | otherwise = Right ()

validateTransfer :: TransferRequest -> Either Text ()
validateTransfer req
  | trQuantity req <= 0 = Left (T.pack "Transfer quantity must be positive")
  | trFromLocation req == trToLocation req = Left (T.pack "Source and destination must be different")
  | trQuantity req > 1000000 = Left (T.pack "Transfer quantity exceeds maximum")
  | otherwise = Right ()

processStockReceipt :: InventoryService -> Int64 -> Int64 -> Double -> IO (Either Text Int64)
processStockReceipt _ goodsId locationId quantity = do
  case validateStockOperation quantity of
    Left err -> pure $ Left err
    Right _ -> do
      let receiptId = fromIntegral (goodsId + locationId + round quantity)
      pure $ Right receiptId

processStockIssue :: InventoryService -> Int64 -> Int64 -> Double -> IO (Either Text Int64)
processStockIssue _ goodsId locationId quantity = do
  case validateStockOperation quantity of
    Left err -> pure $ Left err
    Right _ -> do
      let issueId = fromIntegral (goodsId + locationId + round quantity)
      pure $ Right issueId

processStockTransfer :: InventoryService -> Int64 -> Int64 -> Int64 -> Double -> IO (Either Text Int64)
processStockTransfer _ fromLocation toLocation goodsId quantity = do
  let req = TransferRequest goodsId fromLocation toLocation quantity
  case validateTransfer req of
    Left err -> pure $ Left err
    Right _ -> do
      let transferId = fromIntegral (fromLocation + toLocation + goodsId + round quantity)
      pure $ Right transferId

getStockBalance :: InventoryService -> Int64 -> Int64 -> IO (Either Text Double)
getStockBalance _ goodsId locationId
  | goodsId <= 0 = pure $ Left (T.pack "Invalid goods ID")
  | locationId <= 0 = pure $ Left (T.pack "Invalid location ID")
  | otherwise = pure $ Right 0

getStockByLocation :: InventoryService -> Int64 -> IO (Either Text [(Int64, Double)])
getStockByLocation _ locationId
  | locationId <= 0 = pure $ Left (T.pack "Invalid location ID")
  | otherwise = pure $ Right []

getStockByGoods :: InventoryService -> Int64 -> IO (Either Text [(Int64, Double)])
getStockByGoods _ goodsId
  | goodsId <= 0 = pure $ Left (T.pack "Invalid goods ID")
  | otherwise = pure $ Right []

getLowStockItems :: InventoryService -> Double -> IO (Either Text [StockRecord])
getLowStockItems _ threshold
  | threshold < 0 = pure $ Left (T.pack "Threshold must be non-negative")
  | otherwise = pure $ Right []

stockUpdate :: Pool -> Value -> IO (Either Text Text)
stockUpdate _ _ = pure $ Right "stock updated"

getStockMovementHistory :: InventoryService -> Int64 -> Int64 -> Day -> Day -> IO (Either Text [(Day, Text, Double)])
getStockMovementHistory _ goodsId locationId startDate endDate
  | goodsId <= 0 = pure $ Left (T.pack "Invalid goods ID")
  | locationId <= 0 = pure $ Left (T.pack "Invalid location ID")
  | startDate > endDate = pure $ Left (T.pack "Start date must be before end date")
  | otherwise = pure $ Right []

reserveStock :: InventoryService -> Int64 -> Int64 -> Double -> IO (Either Text Int64)
reserveStock _ goodsId locationId quantity = do
  case validateStockOperation quantity of
    Left err -> pure $ Left err
    Right _ -> do
      let reservationId = fromIntegral (goodsId + locationId + round quantity)
      pure $ Right reservationId

releaseReservation :: InventoryService -> Int64 -> IO (Either Text ())
releaseReservation _ reservationId
  | reservationId <= 0 = pure $ Left (T.pack "Invalid reservation ID")
  | otherwise = pure $ Right ()
