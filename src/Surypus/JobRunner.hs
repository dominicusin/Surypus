{-# LANGUAGE OverloadedStrings #-}

module Surypus.JobRunner
  ( runJobWorker,
    processPendingJobs,
  )
where

import Control.Concurrent (threadDelay)
import Control.Monad (forever)
import Hasql.Pool (Pool)

runJobWorker :: Pool -> Int -> IO ()
runJobWorker _ intervalSeconds = forever $ do
  threadDelay (intervalSeconds * 1000000)
  putStrLn "Job worker tick..."

processPendingJobs :: Pool -> IO Bool
processPendingJobs _ = pure False
