{-# LANGUAGE RecordWildCards #-}

module DB.JobQueue
  ( JobRecord (..),
    enqueueJob,
    fetchPendingJob,
    getJob,
    listJobs,
    setJobStatus,
    logServiceEvent,
    addJobDependency,
    startJobRunning,
  )
where

import Data.Int (Int64)
import Data.Text (Text)
import Domain.Job
  ( JobFilter (..),
    JobRecord (..),
    JobRequest (..),
    JobStatus (..),
    jobStatusFromText,
    jobStatusText,
  )
import Hasql.Pool (Pool)

enqueueJob :: Pool -> JobRequest -> IO Int64
enqueueJob _pool _jr = pure 0

fetchPendingJob :: Pool -> IO (Maybe JobRecord)
fetchPendingJob _pool = pure Nothing

getJob :: Pool -> Int64 -> IO (Maybe JobRecord)
getJob _pool _jobId = pure Nothing

listJobs :: Pool -> Maybe JobFilter -> IO [JobRecord]
listJobs _pool _mf = pure []

setJobStatus :: Pool -> Int64 -> JobStatus -> Maybe Text -> IO Bool
setJobStatus _pool _jobId _status _mError = pure False

logServiceEvent :: Pool -> Text -> IO ()
logServiceEvent _pool _event = pure ()

addJobDependency :: Pool -> Int64 -> Int64 -> IO Bool
addJobDependency _pool _jobId _depId = pure False

startJobRunning :: Pool -> Int64 -> IO Bool
startJobRunning _pool _jobId = pure False
