-- | Notification module - Push notifications
module Core.Notification where

import           Data.Int  (Int64)
import           Data.Text (Text)

-- | Notification - Push notification
data Notification = Notification
  { nId        :: Int64
  , nUserId    :: Int64
  , nTitle     :: Text
  , nBody      :: Text
  , nData      :: Text  -- JSON
  , nStatus    :: NotificationStatus
  , nCreatedAt :: Int64
  } deriving (Show, Eq)

data NotificationStatus = NS_Pending | NS_Sent | NS_Delivered | NS_Read | NS_Failed
  deriving (Show, Eq)

-- | NotificationTemplate - Notification template
data NotificationTemplate = NotificationTemplate
  { ntId        :: Int64
  , ntName      :: Text
  , ntTitle     :: Text
  , ntBody      :: Text
  , ntVariables :: Text  -- JSON
  } deriving (Show, Eq)
