-- | Queue module - Message queues
module Core.Queue where

import           Data.Int  (Int64)
import           Data.Text (Text)
import           Data.Time (UTCTime)

-- | Queue - Message queue
data Queue = Queue
  { qId      :: Int64
  , qName    :: Text
  , qType    :: QueueType
  , qMaxSize :: Int
  , qFlags   :: Int
  } deriving (Show, Eq)

data QueueType = QT_FIFO | QT_Priority | QT_Delay
  deriving (Show, Eq)

-- | QueueMessage - Queue message
data QueueMessage = QueueMessage
  { qmId        :: Int64
  , qmQueueId   :: Int64
  , qmPayload   :: Text  -- JSON
  , qmPriority  :: Int
  , qmStatus    :: MessageStatus
  , qmCreated   :: UTCTime
  , qmProcessed :: Maybe UTCTime
  } deriving (Show, Eq)

data MessageStatus = MS_Pending | MS_Processing | MS_Completed | MS_Failed
  deriving (Show, Eq)

-- | Check queue is empty
isQueueEmpty :: Queue -> Bool
isQueueEmpty q = qMaxSize q == 0
