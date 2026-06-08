{-# LANGUAGE OverloadedStrings #-}
module Audit.Persistence where

import Audit.Trail (AuditEntry (..))
import DAL.Database (ConnectionPool, runDb)
import DAL.Schema
  ( AuditLogEntity (..)
  , EntityField
    ( AuditLogEntityUserId
    , AuditLogEntityCreatedAt
    )
  )
import Data.Int (Int64)
import Data.Text (Text)
import Data.Aeson (encode)
import Database.Persist.Sql (Key, Entity (..), selectList, (==.), entityVal, entityKey, fromSqlKey, insert, deleteWhere, SelectOpt (Desc))
import qualified Data.ByteString.Lazy as LBS

entityWithKeyToEntry :: Key AuditLogEntity -> AuditLogEntity -> AuditEntry
entityWithKeyToEntry key entity =
  AuditEntry
    { aeId = Just (fromSqlKey key)
    , aeTimestamp = auditLogEntityCreatedAt entity
    , aeUserId = auditLogEntityUserId entity
    , aeAction = auditLogEntityAction entity
    , aeResourceType = auditLogEntityResourceType entity
    , aeResourceId = auditLogEntityResourceId entity
    , aeOldValues = auditLogEntityOldValues entity
    , aeNewValues = auditLogEntityNewValues entity
    , aeIpAddress = auditLogEntityIpAddress entity
    }

entryToEntity :: AuditEntry -> AuditLogEntity
entryToEntity entry =
  AuditLogEntity
    { auditLogEntityUserId = aeUserId entry
    , auditLogEntityAction = aeAction entry
    , auditLogEntityResourceType = aeResourceType entry
    , auditLogEntityResourceId = aeResourceId entry
    , auditLogEntityOldValues = aeOldValues entry
    , auditLogEntityNewValues = aeNewValues entry
    , auditLogEntityIpAddress = aeIpAddress entry
    , auditLogEntityCreatedAt = aeTimestamp entry
    }

insertAuditEntry :: ConnectionPool -> AuditEntry -> IO (Either Text Int64)
insertAuditEntry pool entry = do
  let entity = entryToEntity entry
  key <- runDb pool $ insert entity
  pure $ Right (fromSqlKey key)

queryAuditByUser :: ConnectionPool -> Int64 -> IO [AuditEntry]
queryAuditByUser pool userId = do
  entities <- runDb pool $ selectList [AuditLogEntityUserId ==. userId] [Desc AuditLogEntityCreatedAt]
  pure $ map (\e -> entityWithKeyToEntry (entityKey e) (entityVal e)) entities

exportUserData :: ConnectionPool -> Int64 -> IO LBS.ByteString
exportUserData pool userId = do
  entries <- queryAuditByUser pool userId
  pure $ encode entries

anonymizeUserData :: ConnectionPool -> Int64 -> IO ()
anonymizeUserData pool userId = do
  runDb pool $ deleteWhere [AuditLogEntityUserId ==. userId]
  pure ()
