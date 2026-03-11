{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards #-}

module DB.JobQueue
  ( enqueueJob
  , fetchPendingJob
  , getJob
  , listJobs
  , setJobStatus
  , logServiceEvent
  , addJobDependency
  ) where

import Domain.Job
  ( JobFilter(..)
  , JobRecord(..)
  , JobRequest(..)
  , JobStatus(..)
  , jobStatusFromText
  , jobStatusText
  )
import Data.Int (Int64)
import Data.Maybe (fromMaybe)
import Data.Text (Text)
import Data.Time.Clock (UTCTime)
import Hasql.Pool (Pool, use)
import Hasql.Statement (Statement(..))
import qualified Hasql.Decoders as D
import qualified Hasql.Encoders as E
import qualified Hasql.Session as Session

jobRow :: D.Row JobRecord
jobRow =
  JobRecord
    <$> (Just <$> D.column (D.nonNullable D.int8))
    <*> D.column (D.nonNullable D.text)
    <*> D.column (D.nonNullable D.text)
    <*> D.column (D.nonNullable D.text)
    <*> (jobStatusFromText <$> D.column (D.nonNullable D.text))
    <*> D.column (D.nonNullable D.int4)
    <*> D.column (D.nullable D.text)
    <*> D.column (D.nullable D.timestamptz)
    <*> D.column (D.nonNullable D.timestamptz)
    <*> D.column (D.nullable D.timestamptz)
    <*> D.column (D.nullable D.timestamptz)
    <*> D.column (D.nullable D.text)
    <*> D.column (D.nonNullable (D.array (D.element (D.nonNullable D.int8))))

enqueueJob :: Pool -> JobRequest -> IO Int64
enqueueJob pool JobRequest{..} = use pool $
  Session.statement
    ( jrCode
    , jrName
    , jrType
    , jobStatusText JobPending
    , jrPriority
    , jrPayload
    , jrScheduled
    )
    stmt
  where
    stmt = Statement
      "INSERT INTO job (code, name, job_type, status, priority, job_data, scheduled_at) VALUES ($1,$2,$3,$4,$5,$6,$7) RETURNING id"
      (  E.param (E.nonNullable E.text)
      <> E.param (E.nonNullable E.text)
      <> E.param (E.nonNullable E.text)
      <> E.param (E.nonNullable E.text)
      <> E.param (E.nonNullable E.int4)
      <> E.param (E.nullable E.text)
      <> E.param (E.nullable E.timestamptz)
      )
      (D.singleRow $ D.column (D.nonNullable D.int8))
      False

fetchPendingJob :: Pool -> IO (Maybe JobRecord)
fetchPendingJob pool = use pool $
  Session.statement () stmt
  where
    stmt = Statement
      "SELECT j.id, j.code, j.name, j.job_type, j.status, j.priority, j.job_data, j.scheduled_at, j.created_at, j.started_at, j.completed_at, j.error_message, \
      \(SELECT COALESCE(ARRAY_AGG(jd.depends_on_id ORDER BY jd.depends_on_id), ARRAY[]::BIGINT[]) FROM job_dependency jd WHERE jd.job_id = j.id) AS dependencies \
      \FROM job j WHERE j.status = 'pending' \
      \ORDER BY j.priority DESC, j.scheduled_at NULLS LAST, j.created_at DESC \
      \FOR UPDATE SKIP LOCKED LIMIT 1"
      E.noParams
      (D.rowMaybe jobRow)
      False

listJobs :: Pool -> JobFilter -> IO [JobRecord]
listJobs pool JobFilter{..} = use pool $
  Session.statement (maybe Nothing (Just . jobStatusText) jfStatus, jfType) stmt
  where
    stmt = Statement
      "SELECT j.id, j.code, j.name, j.job_type, j.status, j.priority, j.job_data, j.scheduled_at, j.created_at, j.started_at, j.completed_at, j.error_message, \
      \(SELECT COALESCE(ARRAY_AGG(jd.depends_on_id ORDER BY jd.depends_on_id), ARRAY[]::BIGINT[]) FROM job_dependency jd WHERE jd.job_id = j.id) AS dependencies \
      \FROM job j \
      \WHERE ($1 IS NULL OR j.status = $1) \
        \AND ($2 IS NULL OR j.job_type = $2) \
      \ORDER BY j.priority DESC, j.scheduled_at NULLS LAST, j.created_at DESC"
      (  E.param (E.nullable E.text)
      <> E.param (E.nullable E.text)
      )
      (D.rowList jobRow)
      False

getJob :: Pool -> Int64 -> IO (Maybe JobRecord)
getJob pool jid = use pool $
  Session.statement jid stmt
  where
    stmt = Statement
      "SELECT j.id, j.code, j.name, j.job_type, j.status, j.priority, j.job_data, j.scheduled_at, j.created_at, j.started_at, j.completed_at, j.error_message, \
      \(SELECT COALESCE(ARRAY_AGG(jd.depends_on_id ORDER BY jd.depends_on_id), ARRAY[]::BIGINT[]) FROM job_dependency jd WHERE jd.job_id = j.id) AS dependencies \
      \FROM job j WHERE j.id = $1"
      (E.param (E.nonNullable E.int8))
      (D.rowMaybe jobRow)
      False

setJobStatus :: Pool -> Int64 -> JobStatus -> Maybe Text -> IO Bool
setJobStatus pool jid status errMsg = do
  mb <- use pool $
    Session.statement
      ( jid
      , jobStatusText status
      , errMsg
      )
      stmt
  return (mb /= Nothing)
  where
    stmt = Statement
      "UPDATE job SET status = $2, error_message = COALESCE($3, error_message), updated_at = NOW() WHERE id = $1 RETURNING id"
      (  E.param (E.nonNullable E.int8)
      <> E.param (E.nonNullable E.text)
      <> E.param (E.nullable E.text)
      )
      (D.rowMaybe (D.column (D.nonNullable D.int8)))
      False

logServiceEvent :: Pool -> Text -> Text -> IO ()
logServiceEvent pool level message = use pool $
  Session.statement (level, message) stmt
  where
    stmt = Statement
      "INSERT INTO service_events (event_level, event_message) VALUES ($1, $2)"
      (E.param (E.nonNullable E.text) <> E.param (E.nonNullable E.text))
      D.noResult
      False

addJobDependency :: Pool -> Int64 -> Int64 -> Text -> IO Bool
addJobDependency pool jobId dependsOn reason = do
  mb <- use pool $ Session.statement
    ( jobId
    , dependsOn
    , "BLOCKS"
    , reason
    )
    stmt
  return (mb /= Nothing)
  where
    stmt = Statement
      "INSERT INTO job_dependency (job_id, depends_on_id, dependency_type) VALUES ($1, $2, $3) \
      \ON CONFLICT (job_id, depends_on_id) DO UPDATE SET dependency_type = EXCLUDED.dependency_type \
      \RETURNING id"
      (  E.param (E.nonNullable E.int8)
      <> E.param (E.nonNullable E.int8)
      <> E.param (E.nonNullable E.text)
      )
      (D.rowMaybe $ D.column (D.nonNullable D.int8))
      False
