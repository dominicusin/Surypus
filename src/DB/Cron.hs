module DB.Cron
  ( CronTask (..),
    fetchDueCronTasks,
    updateCronTaskNextRun,
    recordCronLog,
  )
where

import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Time as Time
import qualified Hasql.Decoders as D
import qualified Hasql.Encoders as E
import Hasql.Pool (Pool, use)
import qualified Hasql.Session as Session
import Hasql.Statement (Statement)

data CronTask = CronTask
  { ctId :: Int64,
    ctName :: Text,
    ctCommand :: Text,
    ctNextRun :: Time.UTCTime
  }
  deriving (Show, Eq)

cronTaskRow :: D.Row CronTask
cronTaskRow =
  CronTask
    <$> D.column (D.nonNullable D.int8)
    <*> D.column (D.nonNullable D.text)
    <*> D.column (D.nonNullable D.text)
    <*> D.column (D.nonNullable D.timestamptz)

fetchDueCronTasks :: Pool -> IO [CronTask]
fetchDueCronTasks pool = do
  result <- use pool $ Session.statement () stmt
  case result of
    Right x -> pure x
    Left _ -> pure []
  where
    stmt =
      Statement
        "SELECT id, name, command, next_run FROM cron_task WHERE next_run <= now() AND enabled = true ORDER BY next_run"
        E.noParams
        (D.rowList cronTaskRow)

updateCronTaskNextRun :: Pool -> Int64 -> Time.UTCTime -> IO Bool
updateCronTaskNextRun pool taskId nextRun = do
  result <- use pool $ Session.statement (taskId, nextRun) stmt
  case result of
    Right _ -> pure True
    Left _ -> pure False
  where
    stmt =
      Statement
        "UPDATE cron_task SET last_run = now(), next_run = $2 WHERE id = $1"
        (E.param (E.nonNullable E.int8) <> E.param (E.nonNullable E.timestamptz))
        D.noResult

recordCronLog :: Pool -> Int64 -> Text -> Text -> IO Int64
recordCronLog pool taskId status output = do
  result <- use pool $ Session.statement (taskId, status, output) stmt
  case result of
    Right x -> pure x
    Left _ -> pure 0
  where
    stmt =
      Statement
        "INSERT INTO cron_log (task_id, status, output, started_at) VALUES ($1, $2, $3, now()) RETURNING id"
        (E.param (E.nonNullable E.int8) <> E.param (E.nonNullable E.text) <> E.param (E.nonNullable E.text))
        (D.singleRow $ D.column (D.nonNullable D.int8))
