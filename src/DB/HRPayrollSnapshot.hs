{-# LANGUAGE OverloadedStrings #-}

module DB.HRPayrollSnapshot
  ( registerPayrollSnapshot,
    listPayrollSnapshots,
  )
where

import Data.Aeson (eitherDecodeStrict)
import Data.Int (Int64)
import Data.Text (Text)
import Data.Text.Encoding (encodeUtf8)
import Data.Time (Day, UTCTime)
import Domain.HR (SalarySummary (..))
import Domain.Payroll (PayrollSnapshotRecord (..))
import qualified Hasql.Decoders as D
import qualified Hasql.Encoders as E
import Hasql.Pool (Pool, use)
import qualified Hasql.Session as Session
import Hasql.Statement (Statement (..))

registerPayrollSnapshot :: Pool -> Day -> Day -> IO Int64
registerPayrollSnapshot pool start end = use pool $ Session.statement params stmt
  where
    params = (start, end)
    stmt =
      Statement
        "SELECT log_hr_payroll_snapshot($1, $2)"
        ( E.param (E.nonNullable E.date)
            <> E.param (E.nonNullable E.date)
        )
        (D.singleRow $ D.column (D.nonNullable D.int8))
        False

listPayrollSnapshots :: Pool -> IO [PayrollSnapshotRecord]
listPayrollSnapshots pool = use pool $ Session.statement () stmt
  where
    stmt =
      Statement
        "SELECT id, period_start, period_end, created_at, summary::text FROM v_hr_payroll_snapshot"
        E.noParams
        (D.rowList payrollSnapshotRow)
        False

payrollSnapshotRow :: D.Row PayrollSnapshotRecord
payrollSnapshotRow = do
  iid <- D.column (D.nonNullable D.int8)
  pstart <- D.column (D.nonNullable D.date)
  pend <- D.column (D.nonNullable D.date)
  created <- D.column (D.nonNullable D.timestamptz)
  summaryText <- D.column (D.nonNullable D.text)
  case eitherDecodeStrict (encodeUtf8 summaryText) of
    Left err -> fail err
    Right summary ->
      pure
        PayrollSnapshotRecord
          { psrId = iid,
            psrPeriodStart = pstart,
            psrPeriodEnd = pend,
            psrCreatedAt = created,
            psrSummary = summary
          }
