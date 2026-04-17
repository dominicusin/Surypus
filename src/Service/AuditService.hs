{-# LANGUAGE OverloadedStrings #-}

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
import qualified Data.Text as T
import Data.Time (UTCTime, getCurrentTime)
import Hasql.Pool (Pool)

data AuditService = AuditService
  { asPool :: Pool
  }

createAuditService :: Pool -> AuditService
createAuditService = AuditService

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

actionToText :: AuditAction -> Text
actionToText a = case a of
  AuditCreate -> "CREATE"
  AuditRead -> "READ"
  AuditUpdate -> "UPDATE"
  AuditDelete -> "DELETE"
  AuditLogin -> "LOGIN"
  AuditLogout -> "LOGOUT"
  AuditExecute -> "EXECUTE"

textToAction :: Text -> AuditAction
textToAction t = case t of
  "CREATE" -> AuditCreate
  "READ" -> AuditRead
  "UPDATE" -> AuditUpdate
  "DELETE" -> AuditDelete
  "LOGIN" -> AuditLogin
  "LOGOUT" -> AuditLogout
  "EXECUTE" -> AuditExecute
  _ -> AuditRead

entityToText :: AuditEntityType -> Text
entityToText e = case e of
  AuditEntityPerson -> "PERSON"
  AuditEntityGoods -> "GOODS"
  AuditEntityBill -> "BILL"
  AuditEntityOrder -> "ORDER"
  AuditEntityPayment -> "PAYMENT"
  AuditEntityInventory -> "INVENTORY"
  AuditEntityAccounting -> "ACCOUNTING"
  AuditEntityPayroll -> "PAYROLL"
  AuditEntityReport -> "REPORT"
  AuditEntitySystem -> "SYSTEM"

textToEntity :: Text -> AuditEntityType
textToEntity t = case t of
  "PERSON" -> AuditEntityPerson
  "GOODS" -> AuditEntityGoods
  "BILL" -> AuditEntityBill
  "ORDER" -> AuditEntityOrder
  "PAYMENT" -> AuditEntityPayment
  "INVENTORY" -> AuditEntityInventory
  "ACCOUNTING" -> AuditEntityAccounting
  "PAYROLL" -> AuditEntityPayroll
  "REPORT" -> AuditEntityReport
  "SYSTEM" -> AuditEntitySystem
  _ -> AuditEntitySystem

logAuditEvent :: AuditService -> AuditEvent -> IO (Either Text Int64)
logAuditEvent _ _ = do
  _ <- getCurrentTime
  pure $ Right 0

getAuditLog :: AuditService -> Int -> Int -> IO (Either Text [AuditEvent])
getAuditLog _ _ _ = pure $ Right []

getAuditLogByEntity :: AuditService -> AuditEntityType -> Int64 -> IO (Either Text [AuditEvent])
getAuditLogByEntity _ _ _ = pure $ Right []

getAuditLogByUser :: AuditService -> Int64 -> IO (Either Text [AuditEvent])
getAuditLogByUser _ _ = pure $ Right []
