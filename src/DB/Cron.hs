{-# LANGUAGE OverloadedStrings #-}

module DB.Cron
  ( CronTask (..)
  , fetchDueCronTasks
  , updateCronTaskNextRun
  , recordCronLog
  ) where

import Data.Int (Int64)
import Data.Text (Text)
import Hasql.Pool (Pool, use)
import Hasql.Statement (Statement (..))
import qualified Hasql.Decoders as D
import qualified Hasql.Encoders as E
import qualified Hasql.Session as Session

data CronTask = CronTask
  { ctId      :: Int64
  , ctName    :: Text
  , ctCommand :: Text
  } deriving (Show, Eq)

fetchDueCronTasks :: Pool -> IO [CronTask]
fetchDueCronTasks pool = use pool $
  Session.statement () selectCronTasksStatement
  where
    selectCronTasksStatement = Statement
      \"SELECT id, name, command FROM cron_tasks WHERE enabled AND (next_run IS NULL OR next_run <= NOW()) ORDER BY next_run NULLS FIRST LIMIT 5 FOR UPDATE SKIP LOCKED\"
      E.noParams
      (D.rowList cronRowDecoder)
      False

    cronRowDecoder = CronTask
      <$> D.column (D.nonNullable D.int8)
      <*> D.column (D.nonNullable D.text)
      <*> D.column (D.nonNullable D.text)

updateCronTaskNextRun :: Pool -> Int64 -> IO ()
updateCronTaskNextRun pool taskId = use pool $
  Session.statement taskId updateNextRunStatement
  where
    updateNextRunStatement = Statement
      \"UPDATE cron_tasks SET last_run = NOW(), next_run = NOW() + INTERVAL '1 minute' WHERE id = $1\"
      (E.param (E.nonNullable E.int8))
      D.noResult
      False

recordCronLog :: Pool -> Int64 -> Text -> Text -> IO ()
recordCronLog pool taskId status output = use pool $
  Session.statement (taskId, status, output) insertLogStatement
  where
    insertLogStatement = Statement
      \"INSERT INTO cron_logs (task_id, status, output) VALUES ($1, $2, $3)\"
      (E.param (E.nonNullable E.int8) <> E.param (E.nonNullable E.text) <> E.param (E.nonNullable E.text))
      D.noResult
      False
