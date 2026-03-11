{-# LANGUAGE OverloadedStrings #-}

-- | ServiceManager coordinates daemonized jobs and Cron tasks.
module Core.ServiceManager
  ( runDaemon
  , runJobQueueOnce
  , runCronOnce
  , daemonTickDelay
  ) where

import           Control.Concurrent (forkIO, threadDelay)
import           Control.Exception (SomeException, try)
import           Control.Monad (forM_, forever, void)
import qualified Data.Text as T
import           Data.Time.Clock (getCurrentTime)
import           Hasql.Pool (Pool)
import           DB.Cron (CronTask (..), fetchDueCronTasks, recordCronLog,
                         updateCronTaskNextRun)
import           DB.JobQueue (JobRecord (..), fetchPendingJob,
                              logServiceEvent, setJobStatus)

daemonTickDelay :: Int
daemonTickDelay = 5 * 1000000 -- 5 seconds

runJobQueueOnce :: Pool -> IO ()
runJobQueueOnce pool = do
  now <- getCurrentTime
  putStrLn $ "Job queue sweep at " ++ show now
  mjob <- fetchPendingJob pool
  case mjob of
    Nothing -> putStrLn "Job queue idle"
    Just job -> do
      setJobStatus pool (jobRecordId job) "running"
      putStrLn $ "Processing job: " ++ T.unpack (jobRecordType job)
      threadDelay 1000000
      setJobStatus pool (jobRecordId job) "completed"
      logServiceEvent pool "info" ("Job completed: " <> jobRecordType job)

runCronOnce :: Pool -> IO ()
runCronOnce pool = do
  now <- getCurrentTime
  putStrLn $ "Cron tick at " ++ show now
  tasks <- fetchDueCronTasks pool
  if null tasks
    then putStrLn "Cron idle"
    else forM_ tasks $ \task -> do
      let name = ctName task
      recordCronLog pool (ctId task) "running" ("Executing " <> name)
      putStrLn $ "Running cron task: " ++ T.unpack name
      threadDelay 500000
      updateCronTaskNextRun pool (ctId task)
      recordCronLog pool (ctId task) "success" ("Completed " <> name)

-- | Run both job queue and cron loops in parallel.
runDaemon :: Pool -> IO ()
runDaemon pool = do
  putStrLn "Daemon: starting job queue and cron loops"
  void $ forkIO $ forever $ tryRun (runJobQueueOnce pool)
  void $ forkIO $ forever $ tryRun (runCronOnce pool)
  forever $ threadDelay daemonTickDelay

tryRun :: IO () -> IO ()
tryRun action = do
  result <- try action
  case result of
    Left (err :: SomeException) -> putStrLn $ "Daemon tick failed: " ++ T.unpack (T.pack (show err))
    Right () -> return ()
  threadDelay daemonTickDelay
