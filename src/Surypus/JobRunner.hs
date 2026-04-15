{-# LANGUAGE OverloadedStrings #-}

-- | Background Job Runner for Surypus ERP
--
-- This module provides a job queue system for processing long-running
-- tasks asynchronously, such as report generation.
--
-- = Design
--
-- The job system uses:
--
-- * 'TQueue' from STM for thread-safe job queue
-- * Background worker threads for job processing
-- * Simple job types (currently only report jobs)
--
-- = Usage
--
-- @
-- jobQueue <- atomically newTQueue
-- startJobWorker jobQueue
-- submitJob jobQueue (ReportJob "sales_report" (Params "PDF" []))
-- @
module Surypus.JobRunner
  ( runJobWorker,
    processPendingJobs,
    Job (..),
    JobResult (..),
    JobId,
    submitJob,
    startJobWorker,
  )
where

import Control.Concurrent (ThreadId, forkIO, threadDelay)
import Control.Concurrent.STM (TQueue, atomically, readTQueue, writeTQueue)
import Control.Monad (forever)
import Data.Text (Text)
import Hasql.Pool (Pool)
import Surypus.Reports (generateReportJRXML)

-- | Job type
--
-- Represents a unit of work to be processed in the background.
data Job
  = -- | Report generation job
    ReportJob Text Params
  deriving (Show)

-- | Job parameters
--
-- Contains configuration for job execution.
data Params = Params
  { -- | Output format (e.g., "PDF", "Excel")
    pFormat :: Text,
    -- | Report filters
    pFilters :: [(Text, Text)]
  }
  deriving (Show)

-- | Job execution result
data JobResult
  = -- | Job completed successfully with result
    JobSuccess Text
  | -- | Job failed with error message
    JobError Text
  deriving (Show)

-- | Job identifier type
type JobId = Int

-- | Submit a job to the queue
--
-- Adds a job to the background job queue for processing.
-- Returns a job ID (currently a dummy value).
submitJob :: TQueue Job -> Job -> IO JobId
submitJob queue job = do
  atomically $ writeTQueue queue job
  pure 1 -- dummy job id for now

-- | Process a single job
processJob :: Job -> IO JobResult
processJob (ReportJob def _params) = do
  result <- generateReportJRXML def
  case result of
    Just jrxml -> pure $ JobSuccess jrxml
    Nothing -> pure $ JobError "Report generation failed"

-- | Process jobs from queue indefinitely
processJobs :: TQueue Job -> IO ()
processJobs queue = forever $ do
  job <- atomically $ readTQueue queue
  result <- processJob job
  -- Store result or notify
  putStrLn $ "Job completed: " <> show result

-- | Start background job worker
--
-- Spawns a new thread that processes jobs from the queue.
startJobWorker :: TQueue Job -> IO ThreadId
startJobWorker queue = forkIO (processJobs queue)

-- | Legacy job worker (deprecated)
runJobWorker :: Pool -> Int -> IO ()
runJobWorker _ intervalSeconds = forever $ do
  threadDelay (intervalSeconds * 1000000)
  putStrLn "Job worker tick..."

-- | Process pending jobs (legacy)
processPendingJobs :: Pool -> IO Bool
processPendingJobs _ = pure False
