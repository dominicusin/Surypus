-- | Task module - Tasks management
module Core.Task where

import           Data.Int  (Int64)
import           Data.Text (Text)
import           Data.Time (Day)

-- | Task - Task/issue
data Task = Task
  { tskId          :: Int64
  , tskTitle       :: Text
  , tskDescription:: Text
  , tskAssigneeId  :: Int64
  , tskStatus      :: TaskStatus
  , tskPriority    :: Priority
  , tskDueDate     :: Maybe Day
  } deriving (Show, Eq)

data TaskStatus = TS_Open | TS_InProgress | TS_Resolved | TS_Closed
  deriving (Show, Eq)

data Priority = P_Low | P_Medium | P_High | P_Critical
  deriving (Show, Eq)
