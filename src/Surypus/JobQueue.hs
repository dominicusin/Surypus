{-# LANGUAGE OverloadedStrings #-}

module Surypus.JobQueue where

import Control.Concurrent (forkIO, threadDelay)
import Control.Concurrent.STM (TQueue, isEmptyTQueue, newTQueueIO, readTQueue, writeTQueue)
import Control.Monad (forever, when)
import qualified Data.Map.Strict as Map
import Data.Text (Text, pack)
import Data.Time.Clock (UTCTime, getCurrentTime)
import qualified Data.UUID as UUID

-- | Job types matching JobRunner
data JobType
  = PersonSummarySnapshot
  | PayrollSnapshot UTCTime UTCTime
  | ReportRender Text Text
  | ProductionRelease
  deriving (Show, Eq)

-- | Job with dependency support
data Job = Job
  { jobId :: Text,
    jobType :: JobType,
    jobDependencies :: [Text],
    jobCreatedAt :: UTCTime
  }

-- | Job queue state
data JobQueue = JobQueue
  { queueChannel :: TQueue Job,
    queueJobs :: TVar (Map.Map Text Job),
    queueDependencies :: TVar (Map.Map Text [Text])
  }

-- | Initialize job queue
initJobQueue :: IO JobQueue

initQueue = do
  chan <- newTQueueIO
  jobsVar <- newTVarIO Map.empty
  depsVar <- newTVarIO Map.empty
  return $ JobQueue chan jobsVar depsVar

-- | Submit job with dependencies
submitJob :: JobQueue -> Job -> IO Text
submitJob q job = do
  jobId <- either (\_ -> return "0") (\u -> return $ pack $ UUID.toString u) =<< try UUID.nextRandom
  atomically $ do
    writeTQueue (queueChannel q) job
    jobs <- readTVar (queueJobs q)
    writeTVar (queueJobs q) (Map.insert jobId job jobs)
    case jobDependencies job of
      [] -> return ()
      deps -> writeTVar (queueDependencies q) (Map.insert jobId deps =<< readTVar (queueDependencies q))
  return jobId

-- | Dependency resolution check
checkDependencies :: JobQueue -> Text -> IO Bool

dependenciesReady queue depIds = do
  depMap <- readTVarIO (queueDependencies queue)
  return $
    all
      ( \did -> case Map.lookup did depMap of
          Just deps -> null deps
          Nothing -> False
      )
      depIds

-- | Worker with dependency awareness
jobWorker :: JobQueue -> IO ()
jobWorker q = forever $ do
  empty <- isEmptyTQueue (queueChannel q)
  when (not empty) $ do
    job <- atomically $ readTQueue q
    depsOk <- checkDependencies q (jobDependencies job)
    when depsOk $ processJob job
  threadDelay 1000000

processJob :: Job -> IO ()
processJob _ = return ()

-- | Job status tracking
data JobStatus = JobPending | JobRunning | JobCompleted | JobFailed
  deriving (Show, Eq)

-- | Monitor job execution
monitorJobs :: JobQueue -> IO ()
monitorJobs _ = return ()
