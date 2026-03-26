-- | Project module - Project management
module Core.Project where

import Data.Int (Int64)
import Data.Text (Text)
import Data.Time (Day)

-- | Project - Project
data Project = Project
  { prjId :: Int64,
    prjCode :: Text,
    prjName :: Text,
    prjStartDate :: Day,
    prjEndDate :: Maybe Day,
    prjBudget :: Double,
    prjStatus :: ProjectStatus
  }
  deriving (Show, Eq)

data ProjectStatus = PSPlanned | PSInProgress | PSCompleted | PSCancelled
  deriving (Show, Eq)

-- | Task - Project task
data Task = Task
  { tskId :: Int64,
    tskProjectId :: Int64,
    tskName :: Text,
    tskParentId :: Maybe Int64,
    tskStartDate :: Day,
    tskEndDate :: Maybe Day,
    tskStatus :: TaskStatus
  }
  deriving (Show, Eq)

data TaskStatus = TSTodo | TSInProgress | TSDone | TSBlocked
  deriving (Show, Eq)

-- | Check if project is overdue
isProjectOverdue :: Project -> Day -> Bool
isProjectOverdue prj today = case prjEndDate prj of
  Nothing -> False
  Just ed -> today > ed
