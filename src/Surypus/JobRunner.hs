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
import Control.Concurrent.STM (TQueue, atomically, newTQueue, readTQueue, writeTQueue)
import Control.Monad (forever, void)
import Control.Monad.Trans (liftIO)
import qualified DAL.Mutations as Mutations
import DAL.Types (MutationResult (..), QueryResult (..))
import DB.JobQueue (fetchPendingJob, setJobStatus, startJobRunning)
import Data.Aeson (Value, toJSON)
import qualified Data.Aeson as A
import qualified Data.ByteString.Lazy as BL
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text as Text
import qualified Data.Text.Encoding as TE
import qualified Data.Text.IO as TIO
import Domain.Job (JobRecord (..), JobStatus (..))
import Hasql.Pool (Pool)
import qualified Service.InventoryService as IS
import qualified Service.PayrollService as PS
import Surypus.Reports (generateReportJRXML)
import qualified System.CircuitBreaker as CB

data Job
  = ReportJob Text Params
  | PayrollSnapshotJob Value
  | StockUpdateJob Value
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
  pure 1

processJob :: Pool -> Job -> IO JobResult
processJob pool (ReportJob def _params) = do
  result <- generateReportJRXML def
  case result of
    Just jrxml -> pure $ JobSuccess jrxml
    Nothing -> pure $ JobError "Report generation failed"
processJob pool (PayrollSnapshotJob payload) = do
  liftIO $ TIO.putStrLn $ "Processing payroll snapshot: " <> T.pack (show payload)
  pure $ JobSuccess "Payroll snapshot created"
processJob pool (StockUpdateJob payload) = do
  liftIO $ TIO.putStrLn $ "Processing stock update: " <> T.pack (show payload)
  pure $ JobSuccess "Stock updated"

processJobs :: Pool -> TQueue Job -> IO ()
processJobs pool queue = forever $ do
  job <- atomically $ readTQueue queue
  result <- processJob pool job
  putStrLn $ "Job completed: " <> show result

startJobWorker :: Pool -> TQueue Job -> IO ThreadId
startJobWorker pool queue = forkIO (processJobs pool queue)

runJobWorker :: Pool -> Int -> IO ()
runJobWorker pool intervalSeconds = forever $ do
  processed <- processPendingJobs pool
  if processed
    then putStrLn "Job processed successfully"
    else putStrLn "No pending jobs"
  threadDelay (intervalSeconds * 1000000)

processPendingJobs :: Pool -> IO Bool
processPendingJobs pool = do
  mjob <- fetchPendingJob pool
  case mjob of
    Nothing -> return False
    Just job -> do
      let jid = jobId job
          jtype = jobType job
          mpayload = jobData job
          payloadValue :: Value
          payloadValue = case mpayload of
            Just t -> case A.decode (BL.fromStrict (TE.encodeUtf8 t)) of
              Just v -> v
              Nothing -> A.Null
            Nothing -> A.Null
      _ <- startJobRunning pool jid
      result <- case T.toLower jtype of
        "reportjob" -> do
          liftIO $ putStrLn $ "Processing ReportJob id=" ++ show jid
          -- Execute mutation directly to simplify wiring for now
          resMut <- Mutations.reportMutation pool (jobName job)
          case resMut of
            QuerySuccess mr -> case mr of
              MutationResult _ (Just rid) _ -> pure $ JobSuccess (T.pack $ show rid)
              MutationResult _ Nothing _ -> pure $ JobError (T.pack "No mutation id returned")
            QueryError err -> pure $ JobError (Text.pack $ show err)
        "payrollsnapshot" -> do
          liftIO $ putStrLn $ "Processing PayrollSnapshot id=" ++ show jid
          res <- PS.payrollProcessSnapshot pool payloadValue
          case res of
            Right t -> pure $ JobSuccess t
            Left err -> pure $ JobError err
        "stockupdate" -> do
          liftIO $ putStrLn $ "Processing StockUpdate id=" ++ show jid
          res <- IS.stockUpdate pool payloadValue
          case res of
            Right t -> pure $ JobSuccess t
            Left err -> pure $ JobError err
        _ -> do
          liftIO $ putStrLn $ "Unknown job type: " ++ T.unpack jtype
          pure $ JobError $ "Unknown job type: " <> jtype
      case result of
        JobSuccess _ -> void $ setJobStatus pool jid JobCompleted Nothing
        JobError err -> void $ setJobStatus pool jid JobFailed (Just err)
      return True
