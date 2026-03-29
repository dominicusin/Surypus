{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards #-}

module Service.AuditService
  ( AuditService (..),
    createAuditService,
    logAuditEvent,
    getAuditLog,
    getAuditLogByEntity,
    getAuditLogByUser,
    AuditEvent (..),
    AuditAction (..),
    AuditEntityType (..),
  )
where

import Data.Int (Int64)
import Data.Text (Text)
import Data.Time (UTCTime)
import Hasql.Pool (Pool)

data AuditService = AuditService
  {asPool :: Pool}

createAuditService :: Pool -> AuditService
createAuditService = AuditService

logAuditEvent :: AuditService -> AuditEvent -> IO (Either Text Int64)
logAuditEvent _ _ = pure $ Left "Not implemented"

getAuditLog :: AuditService -> Int -> Int -> IO (Either Text [AuditEvent])
getAuditLog _ _ _ = pure $ Left "Not implemented"

getAuditLogByEntity :: AuditService -> AuditEntityType -> Int64 -> IO (Either Text [AuditEvent])
getAuditLogByEntity _ _ _ = pure $ Left "Not implemented"

getAuditLogByUser :: AuditService -> Int64 -> IO (Either Text [AuditEvent])
getAuditLogByUser _ _ = pure $ Left "Not implemented"

data AuditAction
  = AuditCreate
  | AuditRead
  | AuditUpdate
  | AuditDelete
  | AuditLogin
  | AuditLogout
  | AuditExecute

data AuditEntityType
  = AuditEntityPerson
  | AuditEntityGoods
  | AuditEntityBill
  | AuditEntityOrder
  | AuditEntityPayment
  | AuditEntityInventory
  | AuditEntityAccounting
  | AuditEntityPayroll
  | AuditEntityReport
  | AuditEntitySystem

data AuditEvent = AuditEvent
  { auditId :: Maybe Int64,
    auditTimestamp :: UTCTime,
    auditUserId :: Maybe Int64,
    auditUsername :: Text,
    auditAction :: AuditAction,
    auditEntityType :: AuditEntityType,
    auditEntityId :: Maybe Int64,
    auditChanges :: Maybe Text,
    auditIpAddress :: Maybe Text,
    auditDescription :: Text
  }
