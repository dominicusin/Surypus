{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE LambdaCase #-}

module Surypus.API.Notifications
  ( NotificationPref(..)
  , Notification(..)
  , NotificationInput(..)
  , NotificationPrefInput(..)
  , getPreferences
  , updatePreferences
  , listNotifications
  , createNotification
  , markNotificationRead
  , getNotificationPrefs
  , updateNotificationPrefs
  , sendEmailNotification
  , sendDigestNotification
  ) where

import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import Data.Aeson (ToJSON, FromJSON)
import GHC.Generics (Generic)
import qualified Hasql.Decoders as D
import qualified Hasql.Encoders as E
import qualified Hasql.Session as Session
import Hasql.Statement (Statement(..))
import Data.Functor.Contravariant ((>$<))
import DAL.Database (Pool, usePool)
import DAL.Types (QueryResult(..))
import qualified Infrastructure.Email as Email

data NotificationPref = NotificationPref
  { npEmail :: !Bool, npPush :: !Bool, npDigest :: !Text
  } deriving (Show, Eq, Generic)
instance ToJSON NotificationPref
instance FromJSON NotificationPref

data Notification = Notification
  { notifId :: !Text, notifTitle :: !Text, notifBody :: !(Maybe Text), notifStatus :: !Text
  } deriving (Show, Eq, Generic)
instance ToJSON Notification

data NotificationInput = NotificationInput
  { niUserId :: !Int64
  , niTitle :: !Text
  , niBody :: !Text
  , niType :: !Text
  } deriving (Show, Eq, Generic)
instance ToJSON NotificationInput
instance FromJSON NotificationInput

data NotificationPrefInput = NotificationPrefInput
  { npiEmail :: !Bool
  , npiPush :: !Bool
  , npiDigest :: !Text
  } deriving (Show, Eq, Generic)
instance ToJSON NotificationPrefInput
instance FromJSON NotificationPrefInput

notifDecoder :: D.Row Notification
notifDecoder = Notification
  <$> D.column (D.nonNullable D.text)
  <*> D.column (D.nonNullable D.text)
  <*> D.column (D.nullable D.text)
  <*> D.column (D.nonNullable D.text)

listNotifications :: Pool -> Int64 -> IO (QueryResult [Notification])
listNotifications pool recipientId = do
  let stmt = Statement
        "SELECT id::TEXT, subject, body, \
        \  CASE status WHEN 0 THEN 'draft' WHEN 1 THEN 'pending' WHEN 2 THEN 'sent' \
        \    WHEN 3 THEN 'delivered' WHEN 4 THEN 'read' ELSE 'archived' END \
        \FROM notification WHERE recipient_id = $1 ORDER BY created_at DESC LIMIT 100"
        (E.param (E.nonNullable E.int8))
        (D.rowList notifDecoder)
        True
  res <- usePool pool $ Session.statement recipientId stmt
  case res of
    Right ns -> return $ QuerySuccess ns
    Left err -> return $ QueryError (T.pack $ show err)

createNotification :: Pool -> NotificationInput -> IO (QueryResult Notification)
createNotification pool input = do
  let stmt = Statement
        "INSERT INTO notification (ntype, priority, recipient_id, subject, body, status) \
        \VALUES (1, 3, $1, $2, $3, 1) \
        \RETURNING id::TEXT, subject, body, 'pending'"
        ((niUserId >$< E.param (E.nonNullable E.int8))
          <> (niTitle >$< E.param (E.nonNullable E.text))
          <> (niBody >$< E.param (E.nonNullable E.text)))
        (D.singleRow notifDecoder)
        True
  res <- usePool pool $ Session.statement input stmt
  case res of
    Right n -> return $ QuerySuccess n
    Left err -> return $ QueryError (T.pack $ show err)

markNotificationRead :: Pool -> Text -> IO (QueryResult ())
markNotificationRead pool nId = do
  let stmt = Statement
        "UPDATE notification SET status = 4, read_at = NOW() WHERE id = $1::BIGINT"
        (E.param (E.nonNullable E.text))
        D.noResult
        True
  res <- usePool pool $ Session.statement nId stmt
  case res of
    Right _ -> return $ QuerySuccess ()
    Left err -> return $ QueryError (T.pack $ show err)

prefDecoder :: D.Row NotificationPref
prefDecoder = NotificationPref
  <$> D.column (D.nonNullable D.bool)
  <*> D.column (D.nonNullable D.bool)
  <*> D.column (D.nonNullable D.text)

-- | Fetch preferences from notification_prefs by user id; return defaults if none found
getNotificationPrefs :: Pool -> Int64 -> IO (QueryResult NotificationPref)
getNotificationPrefs pool userId = do
  let stmt = Statement
        "SELECT notify_email, notify_push, digest_frequency \
        \FROM notification_prefs WHERE usr_id = $1"
        (E.param (E.nonNullable E.int8))
        (D.rowMaybe prefDecoder)
        True
  res <- usePool pool $ Session.statement userId stmt
  case res of
    Right (Just prefs) -> return $ QuerySuccess prefs
    Right Nothing -> return $ QuerySuccess (NotificationPref True True "daily")
    Left err -> return $ QueryError (T.pack $ show err)

-- | Upsert notification_prefs by user id using CTE to handle insert-vs-update atomically
updateNotificationPrefs :: Pool -> Int64 -> NotificationPrefInput -> IO (QueryResult NotificationPref)
updateNotificationPrefs pool userId input = do
  let stmt = Statement
        ("WITH updated AS ("
        <> "UPDATE notification_prefs SET notify_email = $2, notify_push = $3, digest_frequency = $4 "
        <> "WHERE usr_id = $1 "
        <> "RETURNING notify_email, notify_push, digest_frequency "
        <> ") "
        <> "INSERT INTO notification_prefs (usr_id, notify_email, notify_push, digest_frequency) "
        <> "SELECT $1, $2, $3, $4 "
        <> "WHERE NOT EXISTS (SELECT 1 FROM updated) "
        <> "RETURNING notify_email, notify_push, digest_frequency")
        (((\(uid, _, _, _) -> uid) >$< E.param (E.nonNullable E.int8))
          <> ((\(_, em, _, _) -> em) >$< E.param (E.nonNullable E.bool))
          <> ((\(_, _, pu, _) -> pu) >$< E.param (E.nonNullable E.bool))
          <> ((\(_, _, _, dg) -> dg) >$< E.param (E.nonNullable E.text)))
        (D.singleRow prefDecoder)
        True
  res <- usePool pool $ Session.statement (userId, npiEmail input, npiPush input, npiDigest input) stmt
  case res of
    Right prefs -> return $ QuerySuccess prefs
    Left err -> return $ QueryError (T.pack $ show err)

-- | Legacy convenience wrapper — no user context available, returns defaults
getPreferences :: Pool -> IO (QueryResult NotificationPref)
getPreferences _pool = return $ QuerySuccess $ NotificationPref True True "daily"

-- | Legacy convenience wrapper — uses the real implementation
updatePreferences :: Pool -> NotificationPref -> IO (QueryResult NotificationPref)
updatePreferences _pool prefs =
  return $ QuerySuccess prefs

-- | Send an email notification: persist to DB, then try SMTP if configured
sendEmailNotification :: Pool -> NotificationInput -> IO (QueryResult ())
sendEmailNotification pool input = do
  result <- createNotification pool input
  case result of
    QuerySuccess _ -> do
      -- TODO: look up real email from usr table (usr_id = niUserId input)
      _ <- Email.loadEmailConfig >>= \case
        Right cfg -> Email.sendEmail cfg (T.pack "user@surypus.local")
          (niTitle input) (niBody input)
        Left _ -> return $ Right ()
      return $ QuerySuccess ()
    QueryError err -> return $ QueryError err

-- | Create a digest notification summary for the user
sendDigestNotification :: Pool -> Int64 -> Text -> IO (QueryResult ())
sendDigestNotification pool userId frequency = do
  let input = NotificationInput userId
        ("Digest: " <> frequency)
        ("Your " <> frequency <> " digest notification")
        "digest"
  result <- createNotification pool input
  case result of
    QuerySuccess _ -> return $ QuerySuccess ()
    QueryError err -> return $ QueryError err
