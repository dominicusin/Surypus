{-# LANGUAGE OverloadedStrings #-}

module DB.ReportSchedule
  ( listReportSchedules
  , getReportSchedule
  , createReportSchedule
  , updateReportSchedule
  , deleteReportSchedule
  , logReportSnapshot
  , listReportSnapshots
  ) where

import Data.Int (Int64)
import Data.Text (Text)
import Data.UUID (UUID)
import Data.Time.Clock (UTCTime)
import Hasql.Pool (Pool, use)
import Hasql.Statement (Statement(..))
import qualified Hasql.Encoders as E
import qualified Hasql.Decoders as D
import qualified Hasql.Session as Session
import Domain.ReportSchedule

scheduleRow :: D.Row ReportSchedule
scheduleRow =
  ReportSchedule
    <$> D.column (D.nullable D.int8)
    <*> D.column (D.nonNullable D.text)
    <*> D.column (D.nonNullable D.text)
    <*> D.column (D.nonNullable D.text)
    <*> D.column (D.nullable D.text)
    <*> D.column (D.nonNullable D.bool)
    <*> D.column (D.nullable D.timestamptz)
    <*> D.column (D.nullable D.timestamptz)
    <*> D.column (D.nullable D.timestamptz)

listReportSchedules :: Pool -> IO [ReportSchedule]
listReportSchedules pool = use pool $ Session.statement () stmt
  where
    stmt = Statement
      "SELECT id, name, report_name, cron_expr, params, enabled, next_run, created_at, updated_at FROM report_schedule ORDER BY name"
      E.noParams
      (D.rowList scheduleRow)
      False

getReportSchedule :: Pool -> Int64 -> IO (Maybe ReportSchedule)
getReportSchedule pool rid = use pool $ Session.statement rid stmt
  where
    stmt = Statement
      "SELECT id, name, report_name, cron_expr, params, enabled, next_run, created_at, updated_at FROM report_schedule WHERE id = $1"
      (E.param (E.nonNullable E.int8))
      (D.rowMaybe scheduleRow)
      False

createReportSchedule :: Pool -> ReportScheduleInput -> IO Int64
createReportSchedule pool ReportScheduleInput{..} = use pool $ Session.statement params stmt
  where
    params = (rsiName, rsiReport, rsiCron, rsiParams, rsiEnabled)
    stmt = Statement
      "INSERT INTO report_schedule (name, report_name, cron_expr, params, enabled) VALUES ($1,$2,$3,$4,$5) RETURNING id"
      (  E.param (E.nonNullable E.text)
      <> E.param (E.nonNullable E.text)
      <> E.param (E.nonNullable E.text)
      <> E.param (E.nullable E.jsonb)
      <> E.param (E.nonNullable E.bool)
      )
      (D.singleRow $ D.column (D.nonNullable D.int8))
      False

updateReportSchedule :: Pool -> Int64 -> ReportScheduleInput -> IO Bool
updateReportSchedule pool rid ReportScheduleInput{..} = do
  mb <- use pool $ Session.statement params stmt
  pure (mb /= Nothing)
  where
    params = (rid, rsiName, rsiReport, rsiCron, rsiParams, rsiEnabled)
    stmt = Statement
      "UPDATE report_schedule SET name = $2, report_name = $3, cron_expr = $4, params = $5, enabled = $6, next_run = NOW() + INTERVAL '1 minute' WHERE id = $1 RETURNING id"
      (  E.param (E.nonNullable E.int8)
      <> E.param (E.nonNullable E.text)
      <> E.param (E.nonNullable E.text)
      <> E.param (E.nonNullable E.text)
      <> E.param (E.nullable E.jsonb)
      <> E.param (E.nonNullable E.bool)
      )
      (D.rowMaybe (D.column (D.nonNullable D.int8)))
      False

deleteReportSchedule :: Pool -> Int64 -> IO Bool
deleteReportSchedule pool rid = use pool $ Session.statement rid stmt *> pure True
  where
    stmt = Statement
      "DELETE FROM report_schedule WHERE id = $1"
      (E.param (E.nonNullable E.int8))
      D.noResult
      False

snapshotDecoder :: D.Row ReportSnapshot
snapshotDecoder =
  ReportSnapshot
    <$> D.column (D.nonNullable D.int8)
    <*> D.column (D.nonNullable D.int8)
    <*> D.column (D.nonNullable D.uuid)
    <*> D.column (D.nonNullable D.timestamptz)
    <*> D.column (D.nonNullable D.text)
    <*> D.column (D.nullable D.text)
    <*> D.column (D.nullable D.text)

listReportSnapshots :: Pool -> Int64 -> IO [ReportSnapshot]
listReportSnapshots pool scheduleId = use pool $ Session.statement scheduleId stmt
  where
    stmt = Statement
      "SELECT id, schedule_id, run_id, run_at, status, message, jrxml FROM report_render_snapshot WHERE schedule_id = $1 ORDER BY run_at DESC"
      (E.param (E.nonNullable E.int8))
      (D.rowList snapshotDecoder)
      False

logReportSnapshot :: Pool -> Int64 -> Text -> Maybe Text -> Maybe Text -> IO Int64
logReportSnapshot pool scheduleId status msg jrxml = use pool $ Session.statement params stmt
  where
    params = (scheduleId, status, msg, jrxml)
    stmt = Statement
      "INSERT INTO report_render_snapshot (schedule_id, status, message, jrxml) VALUES ($1,$2,$3,$4) RETURNING id"
      (  E.param (E.nonNullable E.int8)
      <> E.param (E.nonNullable E.text)
      <> E.param (E.nullable E.text)
      <> E.param (E.nullable E.text)
      )
      (D.singleRow $ D.column (D.nonNullable D.int8))
      False
