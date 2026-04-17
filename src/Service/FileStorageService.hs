{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards #-}

module Service.FileStorageService
  ( FileStorageService (..),
    createFileStorageService,
    uploadFile,
    getFile,
    listFiles,
  )
where

import Data.Aeson (Value, object, (.=))
import Data.ByteString (ByteString)
import Data.Int (Int64)
import Data.Text (Text)
import Hasql.Pool (Pool)
import Service.AuditService
  ( AuditAction (..),
    AuditEntityType (..),
    AuditEvent (..),
    AuditService,
    createAuditService,
    logAuditEvent,
  )
import Surypus.Event
  ( DomainEvent (..),
    EventBus,
    EventType (FileDownloaded, FileUploaded),
    publishEventSync,
  )

data FileStorageService = FileStorageService
  { fssPool :: Pool,
    fssEventBus :: EventBus,
    fssAuditService :: AuditService
  }

createFileStorageService :: Pool -> EventBus -> AuditService -> FileStorageService
createFileStorageService pool eb as = FileStorageService pool eb as

uploadFile :: FileStorageService -> Text -> ByteString -> IO (Either Text Int64)
uploadFile service filename content = do
  now <- getCurrentTime
  -- Placeholder: store file, return file_id
  let fileId = 1
  publishEventSync (fssEventBus service) FileUploaded "File" (Just fileId) Nothing (object ["filename" .= filename, "size" .= (fromIntegral $ ByteString.length content) :: Int])
  logToAudit service now AuditCreate AuditEntityFile (Just fileId) ("File uploaded: " <> filename)
  pure (Right fileId)

getFile :: FileStorageService -> Int64 -> IO (Either Text ByteString)
getFile service fileId = do
  now <- getCurrentTime
  -- Placeholder: retrieve file content
  logToAudit service now AuditRead AuditEntityFile (Just fileId) ("File retrieved")
  pure (Right "")

listFiles :: FileStorageService -> IO [Text]
listFiles service = do
  now <- getCurrentTime
  -- Placeholder: list file names
  logToAudit service now AuditRead AuditEntityFile Nothing ("Listed files")
  pure []

logToAudit ::
  FileStorageService ->
  UTCTime ->
  AuditAction ->
  AuditEntityType ->
  Maybe Int64 ->
  Text ->
  IO ()
logToAudit service timestamp action entityType entityId description = do
  let event =
        AuditEvent
          { auditId = Nothing,
            auditTimestamp = timestamp,
            auditUserId = Nothing,
            auditUsername = Nothing,
            auditAction = action,
            auditEntityType = entityType,
            auditEntityId = entityId,
            auditChanges = Nothing,
            auditIpAddress = Nothing,
            auditDescription = Just description
          }
  _ <- logAuditEvent (fssAuditService service) event
  pure ()
