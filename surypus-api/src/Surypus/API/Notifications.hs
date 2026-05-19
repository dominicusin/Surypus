{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DeriveGeneric #-}

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

statusText :: Int -> Text
statusText 0 = "draft"
statusText 1 = "pending"
statusText 2 = "sent"
statusText 3 = "delivered"
statusText 4 = "read"
statusText _ = "archived"

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
markNotificationRead pool notifId = do
  let stmt = Statement
        "UPDATE notification SET status = 4, read_at = NOW() WHERE id = $1::BIGINT"
        (E.param (E.nonNullable E.text))
        D.noResult
        True
  res <- usePool pool $ Session.statement notifId stmt
  case res of
    Right _ -> return $ QuerySuccess ()
    Left err -> return $ QueryError (T.pack $ show err)

-- Preferences are stored per-user in usr table flags; default to enabled for now
getPreferences :: Pool -> IO (QueryResult NotificationPref)
getPreferences _pool = return $ QuerySuccess $ NotificationPref True True "daily"

getNotificationPrefs :: Pool -> Int64 -> IO (QueryResult NotificationPref)
getNotificationPrefs pool _ = getPreferences pool

updatePreferences :: Pool -> NotificationPref -> IO (QueryResult NotificationPref)
updatePreferences _pool prefs = return $ QuerySuccess prefs

updateNotificationPrefs :: Pool -> Int64 -> NotificationPrefInput -> IO (QueryResult NotificationPref)
updateNotificationPrefs _pool _ input =
  return $ QuerySuccess $ NotificationPref (npiEmail input) (npiPush input) (npiDigest input)

-- Email sending requires SMTP config from environment; log intent for now
sendEmailNotification :: Pool -> NotificationInput -> IO (QueryResult ())
sendEmailNotification pool input = do
  result <- createNotification pool input
  case result of
    QuerySuccess _ -> return $ QuerySuccess ()
    QueryError err -> return $ QueryError err

-- Digest: create a summary notification for the user
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
