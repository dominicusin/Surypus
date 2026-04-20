{-# LANGUAGE OverloadedStrings #-}

module Surypus.API.Documents.InventoryDocs
  ( InventoryDocStatus (..),
    InventoryDocument (..),
    createInventoryDocument,
  )
where

import Data.Int (Int64)
import Data.Text (Text)
import Data.Time (UTCTime, getCurrentTime)

data InventoryDocStatus = DocCreated | DocApproved | DocPosted | DocArchived deriving (Show, Eq)

data InventoryDocument = InventoryDocument
  { invDocId :: Int64,
    invDocType :: Text,
    invDocStatus :: InventoryDocStatus,
    invDocCreatedAt :: UTCTime
  }
  deriving (Show, Eq)

createInventoryDocument :: Text -> IO InventoryDocument
createInventoryDocument docType = do
  t <- getCurrentTime
  pure $ InventoryDocument 1 docType DocCreated t
