{-# LANGUAGE OverloadedStrings #-}

module Service.InventoryLifecycleService where

import qualified Data.Text as T
import qualified Surypus.API.Documents.InventoryDocs as InventoryDocs

data InventoryLifecycleService = InventoryLifecycleService

createInventoryLifecycleService :: InventoryLifecycleService
createInventoryLifecycleService = InventoryLifecycleService

postInventoryDocument :: InventoryLifecycleService -> T.Text -> IO (Either T.Text InventoryDocs.InventoryDoc)
postInventoryDocument _ t
  | T.null t = pure (Left (T.pack "Document type must be non-empty"))
  | otherwise = pure (Right (InventoryDocs.InventoryDoc {InventoryDocs.invDocType = T.unpack t}))
