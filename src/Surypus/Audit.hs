{-# LANGUAGE OverloadedStrings #-}

-- | Audit Logging Module - Sensitive operations tracking
module Surypus.Audit
  ( logAuditEvent,
    logCreate,
    logUpdate,
    logDelete,
    logLogin,
    logAccess,
  )
where

import DAL.Types
import Data.Functor.Contravariant ((>$<))
import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import Data.Time (UTCTime, getCurrentTime)
import qualified Hasql.Decoders as D
import qualified Hasql.Encoders as E
import Hasql.Pool (Pool, use)
import qualified Hasql.Session as Session

-- | Audit event parameters type
-- (user_id, action, entity, entity_id, details, timestamp, ip)
type AuditParams = (Maybe Int64, Text, Text, Maybe Int64, Maybe Text, UTCTime, Maybe Text)

-- | Encoder for audit parameters
auditEncoder :: E.Params AuditParams
auditEncoder =
  ((\(a, _, _, _, _, _, _) -> a) >$< E.param (E.nullable E.int8))
    <> ((\(_, b, _, _, _, _, _) -> b) >$< E.param (E.nonNullable E.text))
    <> ((\(_, _, c, _, _, _, _) -> c) >$< E.param (E.nonNullable E.text))
    <> ((\(_, _, _, d, _, _, _) -> d) >$< E.param (E.nullable E.int8))
    <> ((\(_, _, _, _, e, _, _) -> e) >$< E.param (E.nullable E.text))
    <> ((\(_, _, _, _, _, f, _) -> f) >$< E.param (E.nonNullable E.timestamptz))
    <> ((\(_, _, _, _, _, _, g) -> g) >$< E.param (E.nullable E.text))

-- | Log an audit event to the database
logAuditEvent :: Pool -> AuditAction -> Text -> Maybe Int64 -> Maybe Int64 -> Maybe Text -> Maybe Text -> IO (QueryResult Int64)
logAuditEvent pool action entityName mUserId mEntityId mDetails mIP = do
  now <- getCurrentTime
  let sql :: Text
      sql =
        "INSERT INTO audit_log (user_id, action, entity, entity_id, details, timestamp, ip) \
        \VALUES ($1, $2, $3, $4, $5, $6, $7) RETURNING id"
      stmt =
        unpreparable
          sql
          auditEncoder
          (D.singleRow (D.column (D.nonNullable D.int8)))
      actionText :: Text
      actionText = case action of
        AuditCreate -> "CREATE"
        AuditUpdate -> "UPDATE"
        AuditDelete -> "DELETE"
        AuditLogin -> "LOGIN"
        AuditLogout -> "LOGOUT"
        AuditAccess -> "ACCESS"
      params :: AuditParams
      params = (mUserId, actionText, entityName, mEntityId, mDetails, now, mIP)
  result <- use pool $ Session.statement params stmt
  case result of
    Right rid -> pure $ QuerySuccess rid
    Left err -> pure $ QueryError (T.pack $ show err)

-- | Log entity creation
logCreate :: Pool -> Text -> Int64 -> Maybe Text -> IO (QueryResult Int64)
logCreate pool entity eid details = logAuditEvent pool AuditCreate entity Nothing (Just eid) details Nothing

-- | Log entity update
logUpdate :: Pool -> Text -> Int64 -> Maybe Text -> IO (QueryResult Int64)
logUpdate pool entity eid details = logAuditEvent pool AuditUpdate entity Nothing (Just eid) details Nothing

-- | Log entity deletion
logDelete :: Pool -> Text -> Int64 -> Maybe Text -> IO (QueryResult Int64)
logDelete pool entity eid details = logAuditEvent pool AuditDelete entity Nothing (Just eid) details Nothing

-- | Log user login
logLogin :: Pool -> Int64 -> Maybe Text -> IO (QueryResult Int64)
logLogin pool userId details = logAuditEvent pool AuditLogin (T.pack "USER") (Just userId) Nothing details Nothing

-- | Log access to entity
logAccess :: Pool -> Text -> Maybe Int64 -> Maybe Text -> IO (QueryResult Int64)
logAccess pool entity mUserId details = logAuditEvent pool AuditAccess entity mUserId Nothing details Nothing
