-- | Event module - Event logging
module Core.Event where

import           Data.Int  (Int64)
import           Data.Text (Text)
import           Data.Time (UTCTime)

-- | Event - System event
data Event = Event
  { evId      :: Int64
  , evType    :: EventType
  , evObjType :: Int64
  , evObjId   :: Int64
  , evUserId  :: Int64
  , evTime    :: UTCTime
  , evMessage :: Text
  , evFlags   :: Int
  } deriving (Show, Eq)

data EventType = ET_Info | ET_Warning | ET_Error | ET_Audit
  deriving (Show, Eq)

-- | EventSubscription - Event subscription
data EventSubscription = EventSubscription
  { esId        :: Int64
  , esUserId    :: Int64
  , esEventType :: EventType
  , esWebhookId :: Maybe Int64
  , esFlags     :: Int
  } deriving (Show, Eq)

-- | Log event
logEvent :: EventType -> Int64 -> Int64 -> Int64 -> Text -> Event
logEvent et ot oid uid msg = Event 0 et ot oid uid undefined msg 0
