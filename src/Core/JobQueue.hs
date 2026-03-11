-- | JobQueue module - Background jobs
module Core.JobQueue where

import           Data.Int  (Int64)
import           Data.Text (Text)
import           Data.Time (UTCTime)

-- | Job - Background job
data Job = Job
  { jobId       :: Int64
  , jobType     :: JobType
  , jobParams   :: Text  -- JSON
  , jobStatus   :: JobStatus
  , jobPriority :: Int
  , jobCreated  :: UTCTime
  , jobStarted  :: Maybe UTCTime
  , jobFinished :: Maybe UTCTime
  , jobResult   :: Maybe Text
  } deriving (Show, Eq)

data JobType = JT_Sync | JT_Import | JT_Export | JT_Report | JT_Cleanup
  deriving (Show, Eq)

data JobStatus = JS_Pending | JS_Running | JS_Completed | JS_Failed
  deriving (Show, Eq)

-- | JobServer - Job processor
data JobServer = JobServer
  { jsId     :: Int64
  , jsName   :: Text
  , jsHost   :: Text
  , jsPort   :: Int
  , jsStatus :: ServerStatus
  , jsFlags  :: Int
  } deriving (Show, Eq)

data ServerStatus = SS_Online | SS_Offline | SS_Busy
  deriving (Show, Eq)

-- | Check if job is overdue (running > 1 hour)
isJobOverdue :: Job -> UTCTime -> Bool
isJobOverdue job _now = case jobStarted job of
  Nothing  -> False
  Just _st -> jobStatus job == JS_Running
