{-# LANGUAGE OverloadedStrings #-}

module DAL.Repository.AuditLog
  ( AuditLogRepository (..),
    mkAuditLogRepository,
    appendAuditLogRepo,
    listAuditLogsRepo,
    listAuditLogsByEntityTypeRepo,
    listAuditLogsByUserRepo,
  )
where

import Control.Monad.IO.Class (liftIO)
import Control.Monad.Trans.Except (ExceptT, throwE)
import DAL.Repository (RepositoryError (..))
import DAL.Types (AuditAction (..), AuditLog (..))
import Data.Functor.Contravariant ((>$<))
import Data.Int (Int64)
import Data.Maybe (fromMaybe)
import Data.Text (Text)
import qualified Data.Text as T
import Data.Text.Encoding (encodeUtf8)
import Data.Time (getCurrentTime)
import qualified Hasql.Decoders as D
import qualified Hasql.Encoders as E
import Hasql.Pool (Pool, use)
import qualified Hasql.Session as Session
import Hasql.Statement (Statement (..))

newtype AuditLogRepository = AuditLogRepository
  { alRepoPool :: Pool
  }

mkAuditLogRepository :: Pool -> AuditLogRepository
mkAuditLogRepository = AuditLogRepository

mkStatement :: Text -> E.Params params -> D.Result result -> Statement params result
mkStatement sql encoder decoder = Statement (encodeUtf8 sql) encoder decoder True

auditActionToText :: AuditAction -> Text
auditActionToText AuditCreate = "CREATE"
auditActionToText AuditUpdate = "UPDATE"
auditActionToText AuditDelete = "DELETE"
auditActionToText AuditLogin = "LOGIN"
auditActionToText AuditLogout = "LOGOUT"
auditActionToText AuditAccess = "ACCESS"

textToAuditAction :: Text -> AuditAction
textToAuditAction "CREATE" = AuditCreate
textToAuditAction "UPDATE" = AuditUpdate
textToAuditAction "DELETE" = AuditDelete
textToAuditAction "LOGIN" = AuditLogin
textToAuditAction "LOGOUT" = AuditLogout
textToAuditAction "ACCESS" = AuditAccess
textToAuditAction _ = AuditAccess

appendAuditLogRepo :: AuditLogRepository -> Maybe Int64 -> AuditAction -> Text -> Maybe Int64 -> Maybe Text -> Maybe Text -> ExceptT RepositoryError IO Int64
appendAuditLogRepo repo mUserId action entityType mEntityId mDetails mIp = do
  now <- liftIO getCurrentTime
  let stmt =
        mkStatement
          "INSERT INTO audit_log (timestamp, user_id, username, action, entity_type, entity_id, changes, ip_address, description) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9) RETURNING id"
          ( ((\(a, _, _, _, _, _, _, _, _) -> a) >$< E.param (E.nonNullable E.timestamptz))
              <> ((\(_, b, _, _, _, _, _, _, _) -> b) >$< E.param (E.nullable E.int8))
              <> ((\(_, _, c, _, _, _, _, _, _) -> c) >$< E.param (E.nonNullable E.text))
              <> ((\(_, _, _, d, _, _, _, _, _) -> d) >$< E.param (E.nonNullable E.text))
              <> ((\(_, _, _, _, e, _, _, _, _) -> e) >$< E.param (E.nonNullable E.text))
              <> ((\(_, _, _, _, _, f, _, _, _) -> f) >$< E.param (E.nullable E.int8))
              <> ((\(_, _, _, _, _, _, g, _, _) -> g) >$< E.param (E.nullable E.text))
              <> ((\(_, _, _, _, _, _, _, h, _) -> h) >$< E.param (E.nullable E.text))
              <> ((\(_, _, _, _, _, _, _, _, i) -> i) >$< E.param (E.nonNullable E.text))
          )
          (D.singleRow (D.column (D.nonNullable D.int8)))
      params = (now, mUserId, maybe "system" (T.pack . show) mUserId, auditActionToText action, entityType, mEntityId, mDetails, mIp, fromMaybe "" mDetails)
  result <- liftIO . use (alRepoPool repo) $ Session.statement params stmt
  either (throwE . DatabaseError . T.pack . show) pure result

listAuditLogsRepo :: AuditLogRepository -> Int64 -> Int64 -> ExceptT RepositoryError IO [AuditLog]
listAuditLogsRepo repo limit offset = do
  let stmt =
        mkStatement
          "SELECT id, user_id, action, entity_type, entity_id, changes, timestamp, ip_address FROM audit_log ORDER BY timestamp DESC LIMIT $1 OFFSET $2"
          ( (fst >$< E.param (E.nonNullable E.int8))
              <> (snd >$< E.param (E.nonNullable E.int8))
          )
          (D.rowList auditLogDecoder)
  result <- liftIO . use (alRepoPool repo) $ Session.statement (limit, offset) stmt
  either (throwE . DatabaseError . T.pack . show) pure result

listAuditLogsByEntityTypeRepo :: AuditLogRepository -> Text -> Int64 -> Int64 -> ExceptT RepositoryError IO [AuditLog]
listAuditLogsByEntityTypeRepo repo entityType limit offset = do
  let stmt =
        mkStatement
          "SELECT id, user_id, action, entity_type, entity_id, changes, timestamp, ip_address FROM audit_log WHERE entity_type = $1 ORDER BY timestamp DESC LIMIT $2 OFFSET $3"
          ( ((\(a, _, _) -> a) >$< E.param (E.nonNullable E.text))
              <> ((\(_, b, _) -> b) >$< E.param (E.nonNullable E.int8))
              <> ((\(_, _, c) -> c) >$< E.param (E.nonNullable E.int8))
          )
          (D.rowList auditLogDecoder)
  result <- liftIO . use (alRepoPool repo) $ Session.statement (entityType, limit, offset) stmt
  either (throwE . DatabaseError . T.pack . show) pure result

listAuditLogsByUserRepo :: AuditLogRepository -> Int64 -> ExceptT RepositoryError IO [AuditLog]
listAuditLogsByUserRepo repo userId = do
  let stmt =
        mkStatement
          "SELECT id, user_id, action, entity_type, entity_id, changes, timestamp, ip_address FROM audit_log WHERE user_id = $1 ORDER BY timestamp DESC"
          (E.param (E.nonNullable E.int8))
          (D.rowList auditLogDecoder)
  result <- liftIO . use (alRepoPool repo) $ Session.statement userId stmt
  either (throwE . DatabaseError . T.pack . show) pure result

auditLogDecoder :: D.Row AuditLog
auditLogDecoder =
  AuditLog
    <$> D.column (D.nonNullable D.int8)
    <*> D.column (D.nullable D.int8)
    <*> (textToAuditAction <$> D.column (D.nonNullable D.text))
    <*> D.column (D.nonNullable D.text)
    <*> D.column (D.nullable D.int8)
    <*> D.column (D.nullable D.text)
    <*> D.column (D.nonNullable D.timestamptz)
    <*> D.column (D.nullable D.text)
