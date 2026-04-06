{-# LANGUAGE OverloadedStrings #-}

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

data Job
  = ReportJob Text Params
  deriving (Show)

data Params = Params
  { pFormat :: Text,
    pFilters :: [(Text, Text)]
  }
  deriving (Show)

data JobResult
  = JobSuccess Text
  | JobError Text
  deriving (Show)

type JobId = Int

submitJob :: TQueue Job -> Job -> IO JobId
submitJob queue job = do
  atomically $ writeTQueue queue job
  pure 1 -- dummy job id for now

processJob :: Job -> IO JobResult
processJob (ReportJob def _params) = do
  result <- generateReportJRXML def
  case result of
    Just jrxml -> pure $ JobSuccess jrxml
    Nothing -> pure $ JobError "Report generation failed"

processJobs :: TQueue Job -> IO ()
processJobs queue = forever $ do
  job <- atomically $ readTQueue queue
  result <- processJob job
  -- Store result or notify
  putStrLn $ ("Job completed: " <> show result)

startJobWorker :: TQueue Job -> IO ThreadId
startJobWorker queue = forkIO (processJobs queue)

-- Legacy functions
runJobWorker :: Pool -> Int -> IO ()
runJobWorker _ intervalSeconds = forever $ do
  threadDelay (intervalSeconds * 1000000)
  putStrLn "Job worker tick..."

processPendingJobs :: Pool -> IO Bool
processPendingJobs _ = pure False
