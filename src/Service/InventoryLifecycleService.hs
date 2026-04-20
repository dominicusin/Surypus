{-# LANGUAGE OverloadedStrings #-}

module Service.InventoryLifecycleService
  ( InventoryLifecycleService (..),
    createInventoryLifecycleService,
    postInventoryDocument,
  )
where

import Data.Text (Text)
import qualified Data.Text as T
import Hasql.Pool (Pool)
import qualified Surypus.API.Documents.InventoryDocs as InventoryDocs

newtype InventoryLifecycleService = InventoryLifecycleService
  { ilsPool :: Pool
  }

createInventoryLifecycleService :: Pool -> InventoryLifecycleService
createInventoryLifecycleService pool = InventoryLifecycleService pool

-- | Create a new Inventory Document (atomic placeholder: creates a document with DocCreated status)
postInventoryDocument :: InventoryLifecycleService -> Text -> IO (Either Text InventoryDocs.InventoryDocument)
postInventoryDocument _ docType = do
  if T.null (docType)
    then pure $ Left "Document type must be non-empty"
    else do
      doc <- InventoryDocs.createInventoryDocument docType
      pure $ Right doc
