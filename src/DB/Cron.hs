{-# LANGUAGE OverloadedStrings #-}

module DB.Cron
  ( CronTask (..),
    fetchDueCronTasks,
    updateCronTaskNextRun,
    recordCronLog,
  )
where

import Data.Int (Int64)
import Data.Text (Text)

data CronTask = CronTask
  { ctId :: Int64,
    ctName :: Text,
    ctCommand :: Text
  }
  deriving (Show, Eq)

fetchDueCronTasks :: p -> IO [CronTask]
fetchDueCronTasks _pool = pure []

updateCronTaskNextRun :: p -> Int64 -> IO ()
updateCronTaskNextRun _pool _taskId = pure ()

recordCronLog :: p -> Int64 -> Text -> Text -> IO ()
recordCronLog _pool _taskId _status _output = pure ()
