module DB.JobQueue
  ( JobRecord (..),
    enqueueJob,
    fetchPendingJob,
    getJob,
    listJobs,
    setJobStatus,
    logServiceEvent,
    addJobDependency,
  )
where

import Data.Int (Int64)
import Data.Maybe (fromMaybe)
import Data.Text (Text)
import Data.Time.Clock (UTCTime)
import Domain.Job
  ( JobFilter (..),
    JobRecord (..),
    JobRequest (..),
    JobStatus (..),
    jobStatusFromText,
    jobStatusText,
  )
import qualified Hasql.Decoders as D
import qualified Hasql.Encoders as E
import Hasql.Pool (Pool, use)
import qualified Hasql.Session as Session
import Hasql.Statement (Statement (..))

jobRow :: D.Row JobRecord
jobRow =
  JobRecord
    <$> D.column (D.nonNullable D.int8)
    <*> D.column (D.nonNullable D.text)
    <*> D.column (D.nonNullable D.text)
    <*> D.column (D.nonNullable D.text)
    <*> (jobStatusFromText <$> D.column (D.nonNullable D.text))
    <*> (fromIntegral <$> D.column (D.nonNullable D.int4))
    <*> D.column (D.nullable D.text)
    <*> D.column (D.nullable D.timestamptz)
    <*> D.column (D.nonNullable D.timestamptz)
    <*> D.column (D.nullable D.timestamptz)
    <*> D.column (D.nullable D.timestamptz)
    <*> D.column (D.nullable D.text)
    <*> pure [] -- jobDependencies (empty list as placeholder)

enqueueJob :: Pool -> JobRequest -> IO Int64
enqueueJob _ _ = pure 0

fetchPendingJob :: Pool -> IO (Maybe JobRecord)
fetchPendingJob _ = pure Nothing

getJob :: Pool -> Int64 -> IO (Maybe JobRecord)
getJob _ _ = pure Nothing

listJobs :: Pool -> Maybe JobFilter -> IO [JobRecord]
listJobs _ _ = pure []

setJobStatus :: Pool -> Int64 -> JobStatus -> Maybe Text -> IO Bool
setJobStatus _ _ _ _ = pure True

logServiceEvent :: Pool -> Text -> IO ()
logServiceEvent _ _ = pure ()

addJobDependency :: Pool -> Int64 -> Int64 -> IO Bool
addJobDependency _ _ _ = pure True
