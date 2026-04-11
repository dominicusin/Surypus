{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

module Surypus.Audit
  ( SurypusAuditAction (..),
    SurypusAuditLogEntry (..),
    logCreate,
    logUpdate,
    logDelete,
    logRead,
    logAction,
    logAuditEvent,
  )
where

import Control.Monad.Trans.Except (runExceptT)
import qualified DAL.Repository.AuditLog as AuditLogRepo
import DAL.Types (AuditAction (..))
import Data.Aeson (FromJSON, ToJSON)
import Data.Int (Int64)
import Data.Text (Text)
import Data.Time (UTCTime, getCurrentTime)
import GHC.Generics (Generic)
import Hasql.Pool (Pool)

data SurypusAuditAction
  = SurypusAuditCreate
  | SurypusAuditUpdate
  | SurypusAuditDelete
  | SurypusAuditRead
  | SurypusAuditLogin
  | SurypusAuditLogout
  | SurypusAuditPost
  | SurypusAuditCancel
  deriving (Show, Eq, Generic)

instance ToJSON SurypusAuditAction

instance FromJSON SurypusAuditAction

data SurypusAuditLogEntry = SurypusAuditLogEntry
  { salId :: Maybe Int64,
    salUserId :: Int,
    salUserName :: Text,
    salAction :: SurypusAuditAction,
    salEntityType :: Text,
    salEntityId :: Int64,
    salOldValue :: Maybe Text,
    salNewValue :: Maybe Text,
    salTimestamp :: UTCTime,
    salIpAddress :: Maybe Text
  }
  deriving (Show, Eq, Generic)

instance ToJSON SurypusAuditLogEntry

instance FromJSON SurypusAuditLogEntry

logCreate :: Int -> Text -> Text -> Int64 -> Text -> IO SurypusAuditLogEntry
logCreate userId userName entityType entityId newValue = do
  now <- getCurrentTime
  pure $
    SurypusAuditLogEntry
      { salId = Nothing,
        salUserId = userId,
        salUserName = userName,
        salAction = SurypusAuditCreate,
        salEntityType = entityType,
        salEntityId = entityId,
        salOldValue = Nothing,
        salNewValue = Just newValue,
        salTimestamp = now,
        salIpAddress = Nothing
      }

logUpdate :: Int -> Text -> Text -> Int64 -> Text -> Text -> IO SurypusAuditLogEntry
logUpdate userId userName entityType entityId oldValue newValue = do
  now <- getCurrentTime
  pure $
    SurypusAuditLogEntry
      { salId = Nothing,
        salUserId = userId,
        salUserName = userName,
        salAction = SurypusAuditUpdate,
        salEntityType = entityType,
        salEntityId = entityId,
        salOldValue = Just oldValue,
        salNewValue = Just newValue,
        salTimestamp = now,
        salIpAddress = Nothing
      }

logDelete :: Int -> Text -> Text -> Int64 -> Text -> IO SurypusAuditLogEntry
logDelete userId userName entityType entityId oldValue = do
  now <- getCurrentTime
  pure $
    SurypusAuditLogEntry
      { salId = Nothing,
        salUserId = userId,
        salUserName = userName,
        salAction = SurypusAuditDelete,
        salEntityType = entityType,
        salEntityId = entityId,
        salOldValue = Just oldValue,
        salNewValue = Nothing,
        salTimestamp = now,
        salIpAddress = Nothing
      }

logRead :: Int -> Text -> Text -> Int64 -> IO SurypusAuditLogEntry
logRead userId userName entityType entityId = do
  now <- getCurrentTime
  pure $
    SurypusAuditLogEntry
      { salId = Nothing,
        salUserId = userId,
        salUserName = userName,
        salAction = SurypusAuditRead,
        salEntityType = entityType,
        salEntityId = entityId,
        salOldValue = Nothing,
        salNewValue = Nothing,
        salTimestamp = now,
        salIpAddress = Nothing
      }

logAction :: Int -> Text -> SurypusAuditAction -> Text -> Int64 -> Maybe Text -> Maybe Text -> IO SurypusAuditLogEntry
logAction userId userName action entityType entityId oldValue newValue = do
  now <- getCurrentTime
  pure $
    SurypusAuditLogEntry
      { salId = Nothing,
        salUserId = userId,
        salUserName = userName,
        salAction = action,
        salEntityType = entityType,
        salEntityId = entityId,
        salOldValue = oldValue,
        salNewValue = newValue,
        salTimestamp = now,
        salIpAddress = Nothing
      }

logAuditEvent :: Pool -> SurypusAuditAction -> Text -> Maybe Int64 -> Maybe Int64 -> Maybe Text -> Maybe Text -> IO (Either String Int64)
logAuditEvent pool action entityName mUserId mEntityId mDetails mIP = do
  let repo = AuditLogRepo.mkAuditLogRepository pool
      mappedAction = case action of
        SurypusAuditCreate -> AuditCreate
        SurypusAuditUpdate -> AuditUpdate
        SurypusAuditDelete -> AuditDelete
        SurypusAuditRead -> AuditAccess
        SurypusAuditLogin -> AuditLogin
        SurypusAuditLogout -> AuditLogout
        SurypusAuditPost -> AuditUpdate
        SurypusAuditCancel -> AuditUpdate
  result <- runExceptT $ AuditLogRepo.appendAuditLogRepo repo mUserId mappedAction entityName mEntityId mDetails mIP
  pure $ case result of
    Left err -> Left (show err)
    Right auditId -> Right auditId
