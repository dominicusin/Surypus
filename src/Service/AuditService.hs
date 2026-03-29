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
import qualified Data.Text as T
import Data.Time (UTCTime, getCurrentTime)
import qualified Hasql.Decoders as D
import qualified Hasql.Encoders as E
import Hasql.Pool (Pool, use)
import qualified Hasql.Session as Session
import Hasql.Statement (Statement)

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
logAuditEvent service event = do
  now <- getCurrentTime
  result <- use (asPool service) $ do
    Session.execute
      insertAuditEventStmt
      ( now,
        auditUserId event,
        auditUsername event,
        actionToText (auditAction event),
        entityToText (auditEntityType event),
        auditEntityId event,
        auditChanges event,
        auditIpAddress event,
        auditDescription event
      )
    Session.query selectLastAuditIdStmt () :: Session.Session (Session.Result Int64)
  pure $ case result of
    Left err -> Left (T.pack (show err))
    Right [auditId] -> Right auditId
    Right _ -> Left "Failed to get audit ID"

getAuditLog :: AuditService -> Int -> Int -> IO (Either Text [AuditEvent])
getAuditLog service limit offset = do
  result <-
    use (asPool service) $
      Session.query
        selectAuditLogStmt
        ( limit,
          offset
        )
  pure $ case result of
    Left err -> Left (T.pack (show err))
    Right rows -> Right (map rowToEvent rows)

getAuditLogByEntity :: AuditService -> AuditEntityType -> Int64 -> IO (Either Text [AuditEvent])
getAuditLogByEntity service entityType entityId = do
  result <-
    use (asPool service) $
      Session.query
        selectAuditByEntityStmt
        ( entityToText entityType,
          entityId
        )
  pure $ case result of
    Left err -> Left (T.pack (show err))
    Right rows -> Right (map rowToEvent rows)

getAuditLogByUser :: AuditService -> Int64 -> IO (Either Text [AuditEvent])
getAuditLogByUser service userId = do
  result <-
    use (asPool service) $
      Session.query
        selectAuditByUserStmt
        (userId)
  pure $ case result of
    Left err -> Left (T.pack (show err))
    Right rows -> Right (map rowToEvent rows)

rowToEvent :: (Int64, UTCTime, Maybe Int64, Text, Text, Text, Maybe Int64, Maybe Text, Maybe Text, Text) -> AuditEvent
rowToEvent (auditId, timestamp, userId, username, actionText, entityTypeText, entityId, changes, ipAddress, description) =
  AuditEvent
    { auditId = Just auditId,
      auditTimestamp = timestamp,
      auditUserId = userId,
      auditUsername = username,
      auditAction = textToAction actionText,
      auditEntityType = textToEntity entityTypeText,
      auditEntityId = entityId,
      auditChanges = changes,
      auditIpAddress = ipAddress,
      auditDescription = description
    }

insertAuditEventStmt ::
  Statement
    ( UTCTime,
      Maybe Int64,
      Text,
      Text,
      Text,
      Maybe Int64,
      Maybe Text,
      Maybe Text,
      Text
    )
    Int64
insertAuditEventStmt =
  Session.statement
    "INSERT INTO audit_log (timestamp, user_id, username, action, entity_type, entity_id, changes, ip_address, description) \
    \ VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9) RETURNING id"
    ( (,,,,,,,)
        <$> (E.param (E.nonNullable E.timestamptz))
        <*> (E.param (E.nullable E.int8))
        <*> (E.param (E.nonNullable E.text))
        <*> (E.param (E.nonNullable E.text))
        <*> (E.param (E.nonNullable E.text))
        <*> (E.param (E.nullable E.int8))
        <*> (E.param (E.nullable E.text))
        <*> (E.param (E.nullable E.text))
        <*> (E.param (E.nonNullable E.text))
    )
    (D.singleRow (D.column D.nonNullable D.int8))

selectLastAuditIdStmt :: Statement () Int64
selectLastAuditIdStmt =
  Session.statement
    "SELECT currval('audit_log_id_seq')"
    Session.noParams
    (D.singleRow (D.column D.nonNullable D.int8))

selectAuditLogStmt :: Statement (Int, Int) [(Int64, UTCTime, Maybe Int64, Text, Text, Text, Maybe Int64, Maybe Text, Maybe Text, Text)]
selectAuditLogStmt =
  Session.statement
    "SELECT id, timestamp, user_id, username, action, entity_type, entity_id, changes, ip_address, description \
    \ FROM audit_log ORDER BY timestamp DESC LIMIT $1 OFFSET $2"
    ( (,)
        <$> (E.param (E.nonNullable E.int4))
        <*> (E.param (E.nonNullable E.int4))
    )
    ( D.rowList
        ( D.column D.nonNullable D.int8,
          D.column D.nonNullable D.timestamptz,
          D.column D.nullable D.int8,
          D.column D.nonNullable D.text,
          D.column D.nonNullable D.text,
          D.column D.nonNullable D.text,
          D.column D.nullable D.int8,
          D.column D.nullable D.text,
          D.column D.nullable D.text,
          D.column D.nonNullable D.text
        )
    )

selectAuditByEntityStmt :: Statement (Text, Int64) [(Int64, UTCTime, Maybe Int64, Text, Text, Text, Maybe Int64, Maybe Text, Maybe Text, Text)]
selectAuditByEntityStmt =
  Session.statement
    "SELECT id, timestamp, user_id, username, action, entity_type, entity_id, changes, ip_address, description \
    \ FROM audit_log WHERE entity_type = $1 AND entity_id = $2 ORDER BY timestamp DESC"
    ( (,)
        <$> (E.param (E.nonNullable E.text))
        <*> (E.param (E.nonNullable E.int8))
    )
    ( D.rowList
        ( D.column D.nonNullable D.int8,
          D.column D.nonNullable D.timestamptz,
          D.column D.nullable D.int8,
          D.column D.nonNullable D.text,
          D.column D.nonNullable D.text,
          D.column D.nonNullable D.text,
          D.column D.nullable D.int8,
          D.column D.nullable D.text,
          D.column D.nullable D.text,
          D.column D.nonNullable D.text
        )
    )

selectAuditByUserStmt :: Statement Int64 [(Int64, UTCTime, Maybe Int64, Text, Text, Text, Maybe Int64, Maybe Text, Maybe Text, Text)]
selectAuditByUserStmt =
  Session.statement
    "SELECT id, timestamp, user_id, username, action, entity_type, entity_id, changes, ip_address, description \
    \ FROM audit_log WHERE user_id = $1 ORDER BY timestamp DESC"
    (E.param (E.nonNullable E.int8))
    ( D.rowList
        ( D.column D.nonNullable D.int8,
          D.column D.nonNullable D.timestamptz,
          D.column D.nullable D.int8,
          D.column D.nonNullable D.text,
          D.column D.nonNullable D.text,
          D.column D.nonNullable D.text,
          D.column D.nullable D.int8,
          D.column D.nullable D.text,
          D.column D.nullable D.text,
          D.column D.nonNullable D.text
        )
    )
