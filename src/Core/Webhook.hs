-- | Webhook module - Webhooks
module Core.Webhook where

import           Data.Int  (Int64)
import           Data.Text (Text)

-- | Webhook - Webhook configuration
data Webhook = Webhook
  { whId      :: Int64
  , whURL     :: Text
  , whEvent   :: WebhookEvent
  , whSecret  :: Text
  , whEnabled :: Bool
  } deriving (Show, Eq)

data WebhookEvent = WE_BillCreated | WE_BillUpdated | WE_OrderCreated | WE_PaymentReceived
  deriving (Show, Eq)

-- | WebhookLog - Webhook delivery log
data WebhookLog = WebhookLog
  { wlId          :: Int64
  , wlWebhookId   :: Int64
  , wlPayload     :: Text
  , wlResponse    :: Maybe Text
  , wlStatusCode  :: Int
  , wlDeliveredAt :: Int64
  } deriving (Show, Eq)
