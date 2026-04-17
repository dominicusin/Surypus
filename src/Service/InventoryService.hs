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
  )
where

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

validateStockOperation :: Double -> Either Text ()
validateStockOperation qty
  | qty <= 0 = Left (T.pack "Quantity must be positive")
  | qty > 1000000 = Left (T.pack "Quantity exceeds maximum allowed")
  | otherwise = Right ()

processStockReceipt :: InventoryService -> Int64 -> Int64 -> Double -> IO (Either Text Int64)
processStockReceipt _ _ _ _ = pure $ Right 0

processStockIssue :: InventoryService -> Int64 -> Int64 -> Double -> IO (Either Text Int64)
processStockIssue _ _ _ _ = pure $ Right 0

processStockTransfer :: InventoryService -> Int64 -> Int64 -> Int64 -> Double -> IO (Either Text Int64)
processStockTransfer _ _ _ _ _ = pure $ Right 0

getStockBalance :: InventoryService -> Int64 -> Int64 -> IO (Either Text Double)
getStockBalance _ _ _ = pure $ Right 0

getStockByLocation :: InventoryService -> Int64 -> IO (Either Text [(Int64, Double)])
getStockByLocation _ _ = pure $ Right []

getStockByGoods :: InventoryService -> Int64 -> IO (Either Text [(Int64, Double)])
getStockByGoods _ _ = pure $ Right []
