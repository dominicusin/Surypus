{-# LANGUAGE OverloadedStrings #-}

-- | Background Job System - Task queue and execution
module Core.JobSystem
  ( -- * Job Operations
    createJob,
    getJobStatus,
    listJobs,
    listPendingJobs,
    processNextJob,

    -- * Job Types
    JobStatus (..),
    JobPriority (..),
  )
where

import Control.Monad
import DAL.Types
import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import qualified Hasql.Decoders as D
import qualified Hasql.Encoders as E
import Hasql.Pool (Pool, use)
import qualified Hasql.Session as Session
import Hasql.Statement (Statement)

-- | Job execution status
data JobStatus
  = JobPending
  | JobRunning
  | JobCompleted
  | JobFailed
  | JobCancelled
  deriving (Show, Eq)

-- | Job priority levels
data JobPriority
  = PriorityLow
  | PriorityNormal
  | PriorityHigh
  | PriorityCritical
  deriving (Show, Eq)

-- | Create a new job in the queue
createJob :: Pool -> JobInput -> IO (QueryResult Int64)
createJob pool input = do
  let sql =
        "INSERT INTO jobs (job_name, job_status, created_at) \
        \VALUES ($1, $2, CURRENT_TIMESTAMP) RETURNING id"
      stmt =
        Statement
          sql
          (E.param (E.nonNullable E.text) <> E.param (E.nonNullable E.text))
          (D.singleRow (D.column (D.nonNullable D.int8)))
  result <- use pool $ Session.statement (jiName input, jiStatus input) stmt
  case result of
    Right jid -> pure $ QuerySuccess jid
    Left err -> pure $ QueryError (T.pack $ show err)

-- | Get job status by ID
getJobStatus :: Pool -> Int64 -> IO (QueryResult Job)
getJobStatus pool jid = do
  let sql =
        "SELECT id, job_name::text, job_status::text, created_at \
        \FROM jobs WHERE id = $1"
      stmt =
        Statement
          sql
          (E.param (E.nonNullable E.int8))
          (D.rowMaybe jobRowDecoder)
  result <- use pool $ Session.statement jid stmt
  case result of
    Right (Just job) -> pure $ QuerySuccess job
    Right Nothing -> pure $ QueryError "Job not found"
    Left err -> pure $ QueryError (T.pack $ show err)
  where
    jobRowDecoder :: D.Row Job
    jobRowDecoder =
      Job
        <$> D.column (D.nonNullable D.int8)
        <*> D.column (D.nonNullable D.text)
        <*> D.column (D.nonNullable D.text)
        <*> D.column (D.nonNullable D.date)

-- | List all jobs
listJobs :: Pool -> IO (QueryResult [Job])
listJobs pool = do
  let sql =
        "SELECT id, job_name::text, job_status::text, created_at \
        \FROM jobs ORDER BY created_at DESC LIMIT 100"
      stmt = Statement sql E.noParams (D.rowList jobRowDecoder)
  result <- use pool $ Session.statement () stmt
  case result of
    Right jobs -> pure $ QuerySuccess jobs
    Left err -> pure $ QueryError (T.pack $ show err)
  where
    jobRowDecoder :: D.Row Job
    jobRowDecoder =
      Job
        <$> D.column (D.nonNullable D.int8)
        <*> D.column (D.nonNullable D.text)
        <*> D.column (D.nonNullable D.text)
        <*> D.column (D.nonNullable D.date)

-- | List pending jobs count
listPendingJobs :: Pool -> IO (QueryResult Int64)
listPendingJobs pool = do
  let sql = "SELECT COUNT(*) FROM jobs WHERE job_status = 'pending'"
      stmt = Statement sql E.noParams (D.singleRow (D.column (D.nonNullable D.int8)))
  result <- use pool $ Session.statement () stmt
  case result of
    Right count -> pure $ QuerySuccess count
    Left err -> pure $ QueryError (T.pack $ show err)

-- | Process the next pending job
processNextJob :: Pool -> IO (QueryResult (Maybe Job))
processNextJob pool = do
  let selectSql =
        "SELECT id, job_name::text, job_status::text, created_at \
        \FROM jobs WHERE job_status = 'pending' \
        \ORDER BY created_at ASC LIMIT 1 FOR UPDATE SKIP LOCKED"
      selectStmt = Statement selectSql E.noParams (D.rowMaybe jobRowDecoder)
  result <- use pool $ Session.statement () selectStmt
  case result of
    Right (Just job) -> do
      -- Mark as running
      let updateSql = "UPDATE jobs SET job_status = 'running' WHERE id = $1"
          updateStmt =
            Statement
              updateSql
              (E.param (E.nonNullable E.int8))
              (D.singleRow (D.column (D.nonNullable D.int8)))
      _ <- use pool $ Session.statement (jobId job) updateStmt
      pure $ QuerySuccess (Just job)
    Right Nothing -> pure $ QuerySuccess Nothing
    Left err -> pure $ QueryError (T.pack $ show err)
  where
    jobRowDecoder :: D.Row Job
    jobRowDecoder =
      Job
        <$> D.column (D.nonNullable D.int8)
        <*> D.column (D.nonNullable D.text)
        <*> D.column (D.nonNullable D.text)
        <*> D.column (D.nonNullable D.date)
