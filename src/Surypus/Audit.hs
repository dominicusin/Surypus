-- | Audit Logging Module - Sensitive operations tracking
module Surypus.Audit where

import DAL.Types
import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import Data.Time (UTCTime, getCurrentTime)
import qualified Hasql.Decoders as D
import qualified Hasql.Encoders as E
import Hasql.Pool (Pool, use)
import qualified Hasql.Session as Session
import qualified Hasql.Statement as Statement

logAuditEvent :: Pool -> AuditAction -> Text -> Maybe Int64 -> Maybe Text -> Maybe Text -> IO (QueryResult Int64)
logAuditEvent pool action entityName userId entityId details = do
  now <- getCurrentTime
  let sql =
        "INSERT INTO audit_log (user_id, action, entity, entity_id, details, timestamp, ip) \
        \VALUES ($1, $2, $3, $4, $5, $6, $7) RETURNING id"
      stmt =
        Statement.unpreparable
          sql
          ( (E.param (E.nullable E.int8))
              <> (E.param (E.nonNullable E.text))
              <> (E.param (E.nonNullable E.text))
              <> (E.param (E.nullable E.int8))
              <> (E.param (E.nullable E.text))
              <> (E.param (E.nonNullable E.timestamptz))
              <> (E.param (E.nullable E.text))
          )
          (D.singleRow (D.column (D.nonNullable D.int8)))
  let actionText = case action of
        AuditCreate -> "CREATE"
        AuditUpdate -> "UPDATE"
        AuditDelete -> "DELETE"
        AuditLogin -> "LOGIN"
        AuditLogout -> "LOGOUT"
        AuditAccess -> "ACCESS"
  result <-
    use pool $
      Session.statement
        ( userId,
          actionText,
          entityName,
          entityId,
          details,
          now,
          Nothing -- IP would be passed from request context
        )
        stmt
  case result of
    Right rid -> pure $ QuerySuccess rid
    Left err -> pure $ QueryError (T.pack $ show err)

logCreate :: Pool -> Text -> Int64 -> Maybe Text -> IO (QueryResult Int64)
logCreate pool entity eid details = logAuditEvent pool AuditCreate entity (Just eid) Nothing details

logUpdate :: Pool -> Text -> Int64 -> Maybe Text -> IO (QueryResult Int64)
logUpdate pool entity eid details = logAuditEvent pool AuditUpdate entity (Just eid) Nothing details

logDelete :: Pool -> Text -> Int64 -> Maybe Text -> IO (QueryResult Int64)
logDelete pool entity eid details = logAuditEvent pool AuditDelete entity (Just eid) Nothing details

logLogin :: Pool -> Int64 -> Maybe Text -> IO (QueryResult Int64)
logLogin pool userId details = logAuditEvent pool AuditLogin "USER" (Just userId) Nothing details

logAccess :: Pool -> Text -> Maybe Int64 -> Maybe Text -> IO (QueryResult Int64)
logAccess pool entity userId details = logAuditEvent pool AuditAccess entity userId Nothing details
