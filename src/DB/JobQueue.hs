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
import Data.Text (Text)
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
import Hasql.Statement (Statement)

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
enqueueJob pool JobRequest {..} = do
  result <- use pool $ Session.statement (jrName, jrCommand, jrPriority, jrPayload) stmt
  case result of
    Right x -> pure x
    Left _ -> pure 0
  where
    stmt =
      Statement
        "INSERT INTO job_queue (name, command, priority, payload, status, created_at) VALUES ($1, $2, $3, $4, 'pending', now()) RETURNING id"
        ( E.param (E.nonNullable E.text)
            <> E.param (E.nonNullable E.text)
            <> E.param (E.nonNullable E.int4)
            <> E.param (E.nullable E.text)
        )
        (D.singleRow $ D.column (D.nonNullable D.int8))

fetchPendingJob :: Pool -> IO (Maybe JobRecord)
fetchPendingJob pool = do
  result <- use pool $ Session.statement () stmt
  case result of
    Right (j : _) -> pure (Just j)
    Right [] -> pure Nothing
    Left _ -> pure Nothing
  where
    stmt =
      Statement
        "SELECT id, name, command, payload, status, priority, error_message, started_at, created_at, completed_at, next_run, result FROM job_queue WHERE status = 'pending' ORDER BY priority DESC, created_at ASC LIMIT 1 FOR UPDATE SKIP LOCKED"
        E.noParams
        (D.rowMaybe jobRow)

getJob :: Pool -> Int64 -> IO (Maybe JobRecord)
getJob pool jobId = do
  result <- use pool $ Session.statement jobId stmt
  case result of
    Right x -> pure x
    Left _ -> pure Nothing
  where
    stmt =
      Statement
        "SELECT id, name, command, payload, status, priority, error_message, started_at, completed_at, next_run, result FROM job_queue WHERE id = $1"
        (E.param (E.nonNullable E.int8))
        (D.rowMaybe jobRow)

listJobs :: Pool -> Maybe JobFilter -> IO [JobRecord]
listJobs pool (Just JobFilter {..}) = do
  result <- use pool $ Session.statement params stmt
  case result of
    Right x -> pure x
    Left _ -> pure []
  where
    params = (jfStatus, jfLimit, jfOffset)
    stmt =
      Statement
        "SELECT id, name, command, payload, status, priority, error_message, started_at, completed_at, next_run, result FROM job_queue WHERE ($1 IS NULL OR status = $1) ORDER BY created_at DESC LIMIT $2 OFFSET $3"
        ( E.param (E.nullable E.text)
            <> E.param (E.nonNullable E.int4)
            <> E.param (E.nonNullable E.int4)
        )
        (D.rowList jobRow)
listJobs pool Nothing = listJobs pool (Just $ JobFilter Nothing 100 0)

setJobStatus :: Pool -> Int64 -> JobStatus -> Maybe Text -> IO Bool
setJobStatus pool jobId status mError = do
  result <- use pool $ Session.statement (jobId, jobStatusText status, mError) stmt
  case result of
    Right _ -> pure True
    Left _ -> pure False
  where
    stmt =
      Statement
        "UPDATE job_queue SET status = $2, error_message = $3, completed_at = CASE WHEN $2 IN ('completed', 'failed', 'cancelled') THEN now() ELSE NULL END WHERE id = $1"
        ( E.param (E.nonNullable E.int8)
            <> E.param (E.nonNullable E.text)
            <> E.param (E.nullable E.text)
        )
        D.noResult

logServiceEvent :: Pool -> Text -> IO ()
logServiceEvent pool event = do
  _ <- use pool $ Session.statement event stmt
  pure ()
  where
    stmt =
      Statement
        "INSERT INTO job_service_log (event, logged_at) VALUES ($1, now())"
        (E.param (E.nonNullable E.text))
        D.noResult

addJobDependency :: Pool -> Int64 -> Int64 -> IO Bool
addJobDependency pool jobId depId = do
  result <- use pool $ Session.statement (jobId, depId) stmt
  case result of
    Right _ -> pure True
    Left _ -> pure False
  where
    stmt =
      Statement
        "INSERT INTO job_dependencies (job_id, depends_on_id) VALUES ($1, $2) ON CONFLICT DO NOTHING"
        (E.param (E.nonNullable E.int8) <> E.param (E.nonNullable E.int8))
        D.noResult
