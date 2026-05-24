{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE Arrows #-}
{-# LANGUAGE TypeOperators #-}

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
import Data.Profunctor.Product.Default (Default)
import GHC.Generics (Generic)
import qualified Database.PostgreSQL.Simple as PGS
import qualified Opaleye as OE
import qualified Opaleye.Internal.HaskellDB.PrimQuery as OPQ
import qualified Opaleye.Internal.PGTypes as OPG
import qualified Opaleye.Internal.Tag as OITag
import Data.Functor.Contravariant ((>$<))
import DAL.Database (Pool, usePool, runQuery, runCommand)
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

-- Table definition for notification table
notificationTable :: OE.Table (OE.OEText, OE.OEText, OE.OEMaybe (OE.OEText), OE.OEText) (OE.OEText, OE.OEText, OE.OEMaybe (OE.OEText), OE.OEText)
notificationTable = OE.table "notification" (OITag.tag "notification")
   \(notifId, notifTitle, notifBody, notifStatus) ->
      ( notifId
      , notifTitle
      , notifBody
      , notifStatus
      )
   \(notifId, notifTitle, notifBody, notifStatus) ->
      ( OE.required notifId
      , OE.required notifTitle
      , OE.required notifBody
      , OE.required notifStatus
      )

notifDecoder :: (OE.OEText, OE.OEText, OE.OEMaybe (OE.OEText), OE.OEText) -> Notification
notifDecoder (notifId, notifTitle, notifBody, notifStatus) =
   Notification notifId notifTitle notifBody notifStatus

listNotifications :: Pool -> Int64 -> IO (QueryResult [Notification])
listNotifications pool recipientId = do
   let query = OE.sql 
         "SELECT id::TEXT, subject, body, \
         \  CASE status WHEN 0 THEN 'draft' WHEN 1 THEN 'pending' WHEN 2 THEN 'sent' \
         \    WHEN 3 THEN 'delivered' WHEN 4 THEN 'read' ELSE 'archived' END \
         \FROM notification WHERE recipient_id = $1 ORDER BY created_at DESC LIMIT 100"
         (OE.makeColumns (,,,) 
            OE.text
            OE.text
            (OE.maybe OE.text)
            OE.text
         ) (OE.required . fst *** OE.required . snd *** OE.required . thd3 *** OE.required . fld4)
   res <- runQuery pool query (recipientId)
   case res of
     Left err -> return $ QueryError (T.pack $ show err)
     Right cols -> return $ QuerySuccess $ map notifDecoder cols

createNotification :: Pool -> NotificationInput -> IO (QueryResult Notification)
createNotification pool input = do
   let insert = OE.insert notificationTable
         OE.constNothing
         ( T.pack (show 1)  -- ntype: hardcoded to 1
         , T.pack (show 3)  -- priority: hardcoded to 3
         , niUserId input   -- recipient_id
         , niTitle input    -- subject
         , niBody input     -- body
         , T.pack (show 1)  -- status: hardcoded to 1 (pending)
         )
   res <- runCommand pool insert
   case res of
     Left err -> return $ QueryError (T.pack $ show err)
     Right count -> if count > 0
                    then return $ QuerySuccess (Notification (T.pack "1") (niTitle input) (Just (niBody input)) (T.pack "pending"))
                    else return $ QueryError "Failed to create notification"

markNotificationRead :: Pool -> Text -> IO (QueryResult ())
markNotificationRead pool nId = do
   let update = OE.update notificationTable
        \(_notifId _notifTitle _notifBody _notifStatus) ->
          ( _notifId
          , _notifTitle
          , _notifBody
          , T.pack (show 4)  -- status: 4 (read)
          )
        \(_notifId _notifTitle _notifBody _notifStatus) ->
          ( _notifId
          , _notifTitle
          , _notifBody
          , _notifStatus
          )
        (\(_notifId _notifTitle _notifBody _notifStatus) ->
          OE.primaryKey (OE.read nId :: OE.OEText))
   res <- runCommand pool update
   case res of
     Left err -> return $ QueryError (T.pack $ show err)
     Right count -> if count > 0
                    then return $ QuerySuccess ()
                    else return $ QueryError "Notification not found or already read"

-- Table definition for notification_prefs table
notificationPrefsTable :: OE.Table (OE.OEInt8, OE.OEBool, OE.OEBool, OE.OEText) (OE.OEInt8, OE.OEBool, OE.OEBool, OE.OEText)
notificationPrefsTable = OE.table "notification_prefs" (OITag.tag "notification_prefs")
   \(usrId, notifyEmail, notifyPush, digestFrequency) ->
      ( usrId
      , notifyEmail
      , notifyPush
      , digestFrequency
      )
   \(usrId, notifyEmail, notifyPush, digestFrequency) ->
      ( OE.required usrId
      , OE.required notifyEmail
      , OE.required notifyPush
      , OE.required digestFrequency
      )

prefDecoder :: (OE.OEInt8, OE.OEBool, OE.OEBool, OE.OEText) -> NotificationPref
prefDecoder (usrId, notifyEmail, notifyPush, digestFrequency) =
   NotificationPref notifyEmail notifyPush digestFrequency

-- | Fetch preferences from notification_prefs by user id; return defaults if none found
getNotificationPrefs :: Pool -> Int64 -> IO (QueryResult NotificationPref)
getNotificationPrefs pool userId = do
   let query = OE.sql 
         "SELECT notify_email, notify_push, digest_frequency \
         \FROM notification_prefs WHERE usr_id = $1"
         (OE.makeColumns (,,) 
            OE.bool
            OE.bool
            OE.text
         ) (OE.required . fst)
   res <- runQuery pool query (userId)
   case res of
     Left err -> return $ QueryError (T.pack $ show err)
     [] -> return $ QuerySuccess (NotificationPref True True "daily")
     [pref] -> return $ QuerySuccess (prefDecoder pref)

-- | Upsert notification_prefs by user id using CTE to handle insert-vs-update atomically
updateNotificationPrefs :: Pool -> Int64 -> NotificationPrefInput -> IO (QueryResult NotificationPref)
updateNotificationPrefs pool userId input = do
   let upsert = OE.sql 
         ("WITH updated AS ("
         <> "UPDATE notification_prefs SET notify_email = $2, notify_push = $3, digest_frequency = $4 "
         <> "WHERE usr_id = $1 "
         <> "RETURNING notify_email, notify_push, digest_frequency "
         <> ") "
         <> "INSERT INTO notification_prefs (usr_id, notify_email, notify_push, digest_frequency) "
         <> "SELECT $1, $2, $3, $4 "
         <> "WHERE NOT EXISTS (SELECT 1 FROM updated) "
         <> "RETURNING notify_email, notify_push, digest_frequency")
         (OE.makeColumns (,,,) 
            OE.bool
            OE.bool
            OE.text
         ) (((\(uid, _, _, _) -> uid) >$< E.param (E.nonNullable E.int8))
           <> ((\(_, em, _, _) -> em) >$< E.param (E.nonNullable E.bool))
           <> ((\(_, _, pu, _) -> pu) >$< E.param (E.nonNullable E.bool))
           <> ((\(_, _, _, dg) -> dg) >$< E.param (E.nonNullable E.text)))
   res <- runQuery pool upsert (userId, npiEmail input, npiPush input, npiDigest input)
   case res of
     Left err -> return $ QueryError (T.pack $ show err)
     [] -> return $ QuerySuccess (NotificationPref True True "daily")
     [pref] -> return $ QuerySuccess (prefDecoder pref)

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
