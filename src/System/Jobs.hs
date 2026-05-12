module System.Jobs where

import Control.Concurrent.STM (TVar, atomically, newTVarIO, readTVar, writeTVar)
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import Data.Time.Clock (UTCTime, addUTCTime, getCurrentTime)
-- import Database.PostgreSQL.Simple (Connection)
-- import Hasql.Pool (Pool)

-- | Job definitions matching types used by JobRunner
data JobType
  = PersonSummarySnapshot
  | PayrollSnapshot UTCTime UTCTime
  | ReportRender Text Text
  | ProductionRelease
  deriving (Show, Eq)

data Job = Job
  { jobId :: Text,
    jobType :: JobType,
    jobStatus :: TVar JobStatus,
    jobDependencies :: [Text],
    jobCreatedAt :: UTCTime,
    jobError :: TVar (Maybe Text),
    jobResult :: TVar (Maybe Text)
  }

data JobStatus = Pending | Running | Completed UTCTime | Failed Text
  deriving (Show, Eq)

-- | Job runner configuration (simplified)
-- newtype JobRunner = JobRunner {runnerPool :: Pool}

-- | Process pending jobs with dependency resolution
processPendingJobs :: IO ()
processPendingJobs = do
  now <- getCurrentTime
  -- TODO: Fetch pending jobs from database when Database modules are available
  return ()

-- | Dispatch to appropriate job handlers
dispatchJob :: Job -> UTCTime -> IO ()
dispatchJob job now = case jobType job of
  PersonSummarySnapshot -> runPersonSummary job now
  PayrollSnapshot start end -> runPayrollSnapshot job now start end
  ReportRender template format -> runReportRender job now template format
  ProductionRelease -> runProductionRelease job now

-- | Run person summary snapshot job
runPersonSummary :: Job -> UTCTime -> IO ()
runPersonSummary job _now = do
  -- TODO: Implement when database is available
  return ()

-- | Run payroll snapshot job
runPayrollSnapshot :: Job -> UTCTime -> UTCTime -> UTCTime -> IO ()
runPayrollSnapshot job _now _start _end = do
  -- TODO: Implement when database is available
  return ()

-- | Run report render job
runReportRender :: Job -> UTCTime -> Text -> Text -> IO ()
runReportRender job _now _template _format = do
  -- TODO: Implement when database is available
  return ()

-- | Run production release job
runProductionRelease :: Job -> UTCTime -> IO ()
runProductionRelease job _now = do
  -- TODO: Implement when database is available
  return ()

-- | Fetch pending jobs (placeholder)
fetchPendingJobs :: IO [(Job, [String])]
fetchPendingJobs = return []
