module System.Notification where

import Control.Concurrent.STM (TVar, atomically, newTVarIO, readTVar, writeTVar)
import qualified Data.Map.Strict as Map
import qualified Data.Set as Set
import Data.Text (Text)
import Data.Time.Clock (UTCTime)

-- | Notification channels
data NotificationChannel
  = EmailChannel
  | SMSChannel
  | PushChannel
  | WebhookChannel
  deriving (Show, Eq, Ord)

-- | Notification priority
data NotificationPriority
  = Low
  | Normal
  | High
  | Critical
  deriving (Show, Eq, Ord)

-- | Notification payload
data Notification = Notification
  { notificationId :: Text,
    channel :: NotificationChannel,
    priority :: NotificationPriority,
    title :: Text,
    body :: Text,
    recipient :: Text,
    metadata :: Map.Map Text Text,
    scheduledTime :: UTCTime,
    status :: NotificationStatus
  }

-- | Notification delivery status
data NotificationStatus
  = Pending
  | Processing
  | Delivered
  | Failed Text
  | Cancelled
  deriving (Show, Eq)

-- | Notification service configuration
data NotificationConfig = NotificationConfig
  { maxRetries :: Int,
    retryBackoff :: Int,
    channels :: [NotificationChannel],
    rateLimit :: Int
  }

-- | Notification service state
data NotificationService = NotificationService
  { serviceConfig :: NotificationConfig,
    notificationQueue :: TVar [Notification],
    deliveryStatus :: TVar (Map.Map Text NotificationStatus),
    subscribers :: TVar (Map.Map NotificationChannel (Set.Set Text))
  }

-- | Initialize notification service
initNotificationService :: NotificationConfig -> IO NotificationService
initNotificationService config = do
  queue <- newTVarIO []
  status <- newTVarIO Map.empty
  subs <- newTVarIO Map.empty
  return $ NotificationService config queue status subs

-- | Send notification
sendNotification :: NotificationService -> Notification -> IO Text
sendNotification service notif = do
  atomically $ do
    q <- readTVar (notificationQueue service)
    writeTVar (notificationQueue service) (notif : q)
  return $ notificationId notif

-- | Subscribe to channel
subscribeChannel :: NotificationService -> NotificationChannel -> Text -> IO ()
subscribeChannel service channel userId = atomically $ do
  subs <- readTVar (subscribers service)
  let userSet = Map.findWithDefault Set.empty channel subs
      newSet = Set.insert userId userSet
  writeTVar (subscribers service) (Map.insert channel newSet subs)

-- | Publish to subscribers
publishToSubscribers :: NotificationService -> NotificationChannel -> Text -> IO ()
publishToSubscribers service channel message = do
  -- Implementation for pushing notifications
  return ()

-- | Retry failed notifications
retryFailed :: NotificationService -> IO ()
retryFailed service = do
  -- Implementation for retrying failed notifications
  return ()

-- | Cancel notification
cancelNotification :: NotificationService -> Text -> IO ()
cancelNotification service notifId = atomically $ do
  statusMap <- readTVar (deliveryStatus service)
  let updated = Map.insert notifId Cancelled statusMap
  writeTVar (deliveryStatus service) updated
