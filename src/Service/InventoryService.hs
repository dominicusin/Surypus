{-# LANGUAGE RecordWildCards #-}

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
import Hasql.Pool (Pool)

data InventoryService = InventoryService
  {isPool :: Pool}

createInventoryService :: Pool -> InventoryService
createInventoryService = InventoryService

processStockReceipt :: InventoryService -> Int64 -> Int64 -> Double -> IO (Either Text Int64)
processStockReceipt _ _ _ _ = pure $ Left "Not implemented"

processStockIssue :: InventoryService -> Int64 -> Int64 -> Double -> IO (Either Text Int64)
processStockIssue _ _ _ _ = pure $ Left "Not implemented"

processStockTransfer :: InventoryService -> Int64 -> Int64 -> Int64 -> Double -> IO (Either Text Int64)
processStockTransfer _ _ _ _ _ = pure $ Left "Not implemented"

getStockBalance :: InventoryService -> Int64 -> Int64 -> IO (Either Text Double)
getStockBalance _ _ _ = pure $ Left "Not implemented"

getStockByLocation :: InventoryService -> Int64 -> IO (Either Text [(Int64, Double)])
getStockByLocation _ _ = pure $ Left "Not implemented"

getStockByGoods :: InventoryService -> Int64 -> IO (Either Text [(Int64, Double)])
getStockByGoods _ _ = pure $ Left "Not implemented"

validateStockOperation :: Double -> Either Text ()
validateStockOperation _ = Right ()
